import Map "mo:map/Map";
import { ihash } "mo:map/Map";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import { now } "mo:base/Time";
import Types "types";
import { print } "mo:base/Debug";
import IC "mo:ic";

shared ({ caller = BUCKET_MANAGER }) persistent actor class Bucket() = this {

  //// state variables
  var bucketIsReady = false; 
  var memorySize = 0;
  var fileqty = 0;

  let tempFiles = Map.new<Types.FileId, Types.TempFile>();
  let files = Map.new<Types.FileId, Types.File>();

  //// Config variables

  public shared ({ caller }) func init(_uploadDone: Types.CallbackUploadDone, adminsBucket: [Principal]): async { #Ok } {
    assert(caller == BUCKET_MANAGER);
    config := { config with  adminsBucket; uploadDone = ?_uploadDone};
    bucketIsReady := true;
    #Ok
  };
  
  public func status(): async Types.Status { 
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
    uploadDone: ?(shared {internalId: Int} -> async Int) = null;  
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

  public func settings(): async Types.BucketSettingsDefinite {
    config
  };

  /// Private functions

  func authorizedCaller(p : Principal) : Bool {
    if (p == BUCKET_MANAGER) { return true }; 
    for(a in config.adminsBucket.vals()) { if(a == p) { return true } };
    false
  };

  ///

  public shared ({ caller }) func uploadRequest(owner : Principal, size : Nat) : async Types.UploadResponse {
    assert (authorizedCaller(caller));
    assert (size <= (config.maxSize - memorySize : Nat));
    let chunksQty = size / config.chunkSize + (if (size % config.chunkSize > 0) { 1 } else { 0 });
    let chunks : [var Blob] = Prim.Array_init<Blob>(chunksQty, "");
    let id = now();
    let newAsset : Types.TempFile = {
      owner;
      authorizedReaders = [owner];
      id;
      chunks;
      chunks_qty = chunksQty;
      total_length = size;
    };

    ignore Map.put<Types.FileId, Types.TempFile>(tempFiles, ihash, id, newAsset);
    memorySize += size;
    { id; chunksQty; chunkSize = config.chunkSize };
  };

  public shared ({ caller }) func addChunk(id : Int, index : Nat, chunk : Blob) : async { #Ok: ?Int; #Err } {
    switch (Map.get<Types.FileId, Types.TempFile>(tempFiles, ihash, id)) {
      case null { #Err };
      case (?tmp) {
        assert (caller == tmp.owner);
        tmp.chunks[index] := chunk;
        print(debug_show(tmp.chunks));

        //// Si es el ultimo chunk de se activa la verificación e indexado en canister PM
        if (index == (tmp.chunks_qty - 1 : Nat)) {
          // print("chequeando integridad del archivo");
          if (Types.checkFileIntegrity(tmp)) {
            // print("integridad ok");
            
            let callback = switch(config.uploadDone) {
              case ( ?callback ) { callback };
              case null {
                let PM:  actor {callback: shared ({internalId: Int})  -> async Int} = actor(Principal.toText(BUCKET_MANAGER));
                config := {config with uploadDone = ?PM.callback};
                print("Inicializando funcion callback");
                PM.callback
              };
            };
            
            let fileId = await callback({internalId = id});

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

};
