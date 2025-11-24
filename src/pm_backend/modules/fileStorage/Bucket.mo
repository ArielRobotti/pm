import Map "mo:map/Map";
import { ihash } "mo:map/Map";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
import { now } "mo:base/Time";
import Types "types";
import { print } "mo:base/Debug";

shared ({ caller = BUCKET_MANAGER }) persistent actor class Bucket(uploadDone: Types.CallbackUploadDone) = this {

  //// state variables
  var memorySize = 0;
  var fileqty = 0;

  let tempFiles = Map.new<Types.FileId, Types.TempFile>();
  let files = Map.new<Types.FileId, Types.File>();

  //// Config variables

  var config: Types.BucketSettingsDefinite = {
    maxSize = 200 * 1024 * 1024 * 1024;
    chunkSize = 1_048_576; // Tamaño en Bytes de los "Chuncks" 1_048_576 //1MB
    externalAdmins: [Principal] = [];
  };

  ///// Getters

  public query func getBalance() : async Nat { Prim.cyclesBalance() };
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
    let externalAdmins = switch optAdmins {case null config.externalAdmins; case (?v) v};
    config := {maxSize; chunkSize; externalAdmins};
    #Ok
  };

  public func settings(): async Types.BucketSettingsDefinite {
    config
  };

  /// Private functions

  func authorizedCaller(p : Principal) : Bool {
    if (p == BUCKET_MANAGER) { return true }; 
    for(a in config.externalAdmins.vals()) { if(a == p) { return true } };
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
        if (index == (tmp.chunks_qty - 1 : Nat)) {
          print("chequeando integridad del archivo");
          if (Types.checkFileIntegrity(tmp)) {
            let newFile : Types.File = {
                tmp with
                chunks = Prim.Array_tabulate<Blob>(tmp.chunks_qty, func x = tmp.chunks[x])
            };
            ignore Map.put<Types.FileId, Types.File>(files, ihash, id, newFile);
            ignore Map.remove<Types.FileId, Types.TempFile>(tempFiles, ihash, id);
            // 1: uploadRequest desde main
            // 2: response: internalId ...
            // 3: add all chunks from frotend to internalId
            // 4: push upload file done in main for index 
            // 5: main return fileId;
            let fileId = await uploadDone({internalId = id});
            return #Ok(?fileId)
          } else {
            return #Err;
          };
        };
        #Ok(null)
        
      };
    };
  };

};
