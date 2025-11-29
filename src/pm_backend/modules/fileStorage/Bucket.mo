import Map "mo:map/Map";
import Set "mo:map/Set";
import { ihash; phash } "mo:map/Map";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import { now } "mo:base/Time";
import Types "types";
import { print } "mo:base/Debug";
// import IC "mo:ic";

shared ({ caller = BUCKET_MANAGER }) persistent actor class Bucket() = this {

  //// Canister references 

  let pm_canister = actor(Principal.toText(BUCKET_MANAGER)): actor {
    onFileLoaded: shared ({internalId: Int; tempIdSource: ?Int})  -> async Int
  };

  //// state variables
  var bucketIsReady = false; 
  var memorySize = 0;
  var fileqty = 0;

  let tempFiles = Map.new<Types.FileId, Types.TempFile>();
  let files = Map.new<Types.FileId, Types.File>();

  //// Config variables

  public shared ({ caller }) func init( adminsBucket: [Principal]): async { #Ok } {
    assert(caller == BUCKET_MANAGER);
    config := { config with  adminsBucket};
    bucketIsReady := true;
    #Ok
  };
  
  public query func status(): async Types.Status { 
    {
      rts = {rts_callback_table_count = Prim.rts_callback_table_count();
      rts_callback_table_size  = Prim.rts_callback_table_size();
      rts_collector_instructions  = Prim.rts_collector_instructions();
      rts_heap_size  = Prim.rts_heap_size();
      rts_logical_stable_memory_size = Prim.rts_logical_stable_memory_size();
      rts_max_live_size = Prim.rts_max_live_size();
      rts_max_stack_size = Prim.rts_max_stack_size();
      rts_memory_size = Prim.rts_memory_size();
      rts_mutator_instructions = Prim.rts_mutator_instructions();
      rts_reclaimed = Prim.rts_reclaimed();
      rts_stable_memory_size = Prim.rts_stable_memory_size();
      rts_total_allocation = Prim.rts_total_allocation();
      rts_upgrade_instructions = Prim.rts_upgrade_instructions();
      rts_version = Prim.rts_version();
      };
      canister = {
        balance = Prim.cyclesBalance();
      }
    }
  };

  var config: Types.BucketSettingsDefinite = {
    maxSize = 200 * 1024 * 1024 * 1024;
    chunkSize = 1_048_576; // Tamaño en Bytes de los "Chuncks" 1_048_576 //1MB
    adminsBucket: [Principal] = [];
  };

  ///// Getters

  public query func getSize() : async Nat { memorySize };
  public query func getFilesQty() : async Nat { fileqty };
  public query func getMemoryAllowed() : async Nat { config.maxSize - memorySize };


  /// Admin functions

  public shared ({ caller }) func updateSettings(values: Types.BucketSettings): async {#Ok; #Err}{
    if(not authorizedCaller(caller)) { 
      return #Err 
    };
    let { optMaxSize; optAdmins; optChunkSize } = values;
    let maxSize = switch optMaxSize {case null config.maxSize; case (?v) v};
    let chunkSize = switch optChunkSize {case null config.chunkSize; case (?v) v};
    let adminsBucket = switch optAdmins {case null config.adminsBucket; case (?v) v};
    config := {config with maxSize; chunkSize; adminsBucket};
    #Ok
  };

  public query func settings(): async Types.BucketSettingsDefinite {
    config
  };

  /// Private functions

  func authorizedCaller(p : Principal) : Bool {
    if (p == BUCKET_MANAGER) { return true }; 
    for(a in config.adminsBucket.vals()) { if(a == p) { return true } };
    false
  };

  func flattenAndDeduplicate<T>(m: [[T]], hashEqFn: (T -> Nat32, (T, T) -> Bool)): [T]{
    let set = Set.new<T>();
    for (array in m.vals()){
      for (e in array.vals()) {
        ignore Set.put<T>(set, hashEqFn, e);
      }
    };
    Set.toArray(set);
  };

  ///

  public shared ({ caller }) func uploadRequest(owner : Principal, readers: [Principal], size : Nat, tempIdSource: ?Int) : async Types.UploadResponse {
    assert (authorizedCaller(caller));
    assert (size <= (config.maxSize - memorySize : Nat));
    let chunksQty = size / config.chunkSize + (if (size % config.chunkSize > 0) { 1 } else { 0 });
    let chunks : [var Blob] = Prim.Array_init<Blob>(chunksQty, "");
    let id = now();
    let authorizedReaders: [Principal] = flattenAndDeduplicate<Principal>([[owner, caller], readers], phash);
    print(debug_show(authorizedReaders));
    let newAsset : Types.TempFile = {
      owner;
      authorizedReaders; // TODO revisar si es necesario recibir los miembros autorizados
      id;
      tempIdSource;
      chunks;
      chunks_qty = chunksQty;
      chunk_size = config.chunkSize;
      total_length = size;
    };

    ignore Map.put<Types.FileId, Types.TempFile>(tempFiles, ihash, id, newAsset);
    memorySize += size;
    { id; chunksQty; chunkSize = config.chunkSize };
  };

  public shared ({ caller }) func addChunk(id : Int, index : Nat, chunk : Blob) : async { #Ok: ?Int; #Err} {
    switch (Map.get<Types.FileId, Types.TempFile>(tempFiles, ihash, id)) {
      case null { #Err };
      case (?tmp) {
        assert (caller == tmp.owner);

        // Verificar tamaño del chunk antes de guardarlo
        if(chunk.size() != tmp.chunk_size) {
          if(index < (tmp.chunks_qty - 1 : Nat) or chunk.size() != tmp.total_length % tmp.chunk_size) {
            print("Chunk de tamaño incorrecto");
            return #Err
          }
        };

        tmp.chunks[index] := chunk;
        //// Si es el ultimo chunk de se activa la verificación e indexado en canister PM
        if (index == (tmp.chunks_qty - 1 : Nat)) {
          if (Types.checkFileIntegrity(tmp)) {
            let fileId = await pm_canister.onFileLoaded({internalId = id; tempIdSource = tmp.tempIdSource}); // Notificacion para indexado en pm
            let newFile : Types.File = {
                tmp with
                chunks = Prim.Array_tabulate<Blob>(tmp.chunks_qty, func x = tmp.chunks[x])
            };
            ignore Map.put<Types.FileId, Types.File>(files, ihash, id, newFile);
            ignore Map.remove<Types.FileId, Types.TempFile>(tempFiles, ihash, id);
            return #Ok(?fileId)
  
          } else {
            print("Error integridad de archivo: require size = " # debug_show(tmp.total_length) # "Chunk size = " # debug_show(chunk.size()));
            return #Err;
          };
        };
        #Ok(null)
      };
    };
  };

  func included<T>(arr: [T], e: T, eq: (T, T) -> Bool): Bool {
    for (_e in arr.vals()){
      if (eq(e, _e)) { return true }
    };
    false
  };

  public shared query ({ caller }) func getFileMetadata(fileId: Int): async ?Types.File {
    Map.get<Int, Types.File>(files, ihash, fileId)
  };

  public shared query ({ caller }) func getChunk(fileId: Int, index: Nat): async {#Ok: {chunk: Blob; hasNext: Bool}; #Err: Text } {
    switch (Map.get<Int, Types.File>(files, ihash, fileId)){
      case null #Err("File not found");
      case ( ?file ) {
        if(file.chunks.size() < index ) { 
          return #Err("Index out of bounds") 
        };
        if(not included<Principal>(file.authorizedReaders, caller, Principal.equal)) {
          return #Err("Access denied")
        };
        #Ok({chunk = file.chunks[index]; hasNext = file.chunks.size() > index + 1 })
      };
    }
  };



};
