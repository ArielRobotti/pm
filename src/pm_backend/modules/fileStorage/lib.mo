import Map "mo:map/Map";
import { phash; ihash } "mo:map/Map";
import Prim "mo:⛔";
import IC "mo:ic";
import Principal "mo:base/Principal";
// import { now } "mo:base/Time";
import Types "types";
import Bucket "Bucket";
import { print } "mo:base/Debug";


module {

  // -----------------------------------------------
  // 1. Tipos de Utilidad / Base (Base Types)
  // -----------------------------------------------

  public type FileId = Int;

  public type Bucket = Bucket.Bucket;

  public type StorageLocation = Types.StorageLocation;

  public type FileMetadata = Types.FileMetadata;

  public type TempFile = FileMetadata and {
    chunks : [var Blob];
  };

  public type File = FileMetadata and {
    chunks : [Blob];
  };

  // -----------------------------------------------
  // 2. Tipos de Entidad Principal (Main Entity Types)
  // -----------------------------------------------

  public type BucketMetadata = {
    remoteActor : Bucket.Bucket;
    canisterId : Principal;
  };


  public type GetStorageResponse = {
    bucketMetadata: BucketMetadata;
    uploadParameters: Types.UploadResponse;
  };
  
  public type CallbackUploadDone = Types.CallbackUploadDone; 

  // -----------------------------------------------
  // 4. Tipo de Estado (State Type)
  // -----------------------------------------------

  public type FileStorage = {
    index : Map.Map<Int, StorageLocation>;
    buckets : Map.Map<Principal, BucketMetadata>;
    bucketAdmins: [Principal];
  };

  // -----------------------------------------------
  // 5. Funciones Privadas
  // -----------------------------------------------

  func addControllers(canister_id: Principal, _controllers: [Principal]): async () {
    let ic = IC.ic;
    let currentSettings = (await ic.canister_status({ canister_id } )).settings;

    let controllers = Prim.Array_tabulate<Principal>(
      _controllers.size() + currentSettings.controllers.size(),
      func x = if (x < _controllers.size()) {_controllers[x]} else { currentSettings.controllers [ x - _controllers.size()]}
    );
    
    let update_settings_args = {
      canister_id;
		  settings: IC.CanisterSettings  = {
        controllers = ?controllers;
        compute_allocation = ?currentSettings.compute_allocation;
        freezing_threshold = ?currentSettings.compute_allocation;
        log_visibility = ?currentSettings.log_visibility;
        memory_allocation = ?currentSettings.memory_allocation;
        reserved_cycles_limit = ?currentSettings.reserved_cycles_limit;
        wasm_memory_limit = ?currentSettings.wasm_memory_limit;
        wasm_memory_threshold  = ?currentSettings.wasm_memory_threshold;
      };
		  sender_canister_version: ?Nat64 = null;
    };
    ignore ic.update_settings(update_settings_args);
  };

  public type CanisterStatusResult = IC.CanisterStatusResult;
  public func canisterStatus(canister_id: Principal): async CanisterStatusResult{
    await IC.ic.canister_status({canister_id})
  };

  func newBucket(s: FileStorage) : async BucketMetadata {

    let newBucket = await (with cycles = 2_000_000_000_000) Bucket.Bucket();
    let initResponse = await newBucket.init(s.bucketAdmins);
    print("New bucket initialized --> " # debug_show (initResponse));
    let canisterId = Principal.fromActor(newBucket);
    print("Adding controllers to the new canister ... ");
    ignore addControllers(canisterId, s.bucketAdmins);
    { canisterId ; remoteActor = newBucket };
  };

  // -----------------------------------------------
  // 5. Funciones Publicas
  // -----------------------------------------------
  
  public func init({bucketAdmins: [Principal]}): FileStorage {
   { 
    index = Map.new<FileId, StorageLocation>();
    buckets =  Map.new<Principal, BucketMetadata>();
    bucketAdmins ;
   }
  };

  public func getStorageFor(s : FileStorage, size : Nat, caller : Principal, readers: [Principal], tempIdSource: ?Int) : async GetStorageResponse {
    print("solicitando almacenamiento");
    var bestCandidate : ?{ bucket : BucketMetadata; size : Nat } = null;
    for (metadata in Map.vals(s.buckets)) {
      let bucketSize = await metadata.remoteActor.getMemoryAllowed();
      print(debug_show(bucketSize));
      if (bucketSize >= size) {
        switch bestCandidate {
          case null {
            bestCandidate := ?{ bucket = metadata; size = bucketSize };
          };
          case (?candidate) {
            bestCandidate := if (candidate.size < bucketSize) {
              bestCandidate;
            } else {
              ?{ bucket = metadata; size = bucketSize };
            };
          };
        };
      };
    };

    let storage = switch bestCandidate {
      case null { await newBucket(s) };
      case (?best) { best.bucket };
    };
    ignore Map.put<Principal, BucketMetadata>(s.buckets, phash, storage.canisterId, storage);

    let uploadParameters = await storage.remoteActor.uploadRequest(caller, readers, size, tempIdSource);
    {bucketMetadata  = storage; uploadParameters };

  };

  public func indexFile(s: FileStorage, id: Int, newFileMetadata: StorageLocation): () {
    ignore Map.put<Int, StorageLocation>(s.index, ihash, id, newFileMetadata)
  };

  public func isBucketCanister(s: FileStorage, p: Principal): Bool {
    Map.has<Principal, BucketMetadata>(s.buckets , phash, p)
  }

  
};

  