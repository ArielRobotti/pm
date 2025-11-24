import Map "mo:map/Map";
import { phash; ihash } "mo:map/Map";
import Prim "mo:⛔";
import Principal "mo:base/Principal";
// import { now } "mo:base/Time";
import Types "types";
import Bucket "Bucket";
import { print } "mo:base/Debug";


module {

  // ===============================================
  // 1. Tipos de Utilidad / Base (Base Types)
  // ===============================================

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

  // ===============================================
  // 2. Tipos de Entidad Principal (Main Entity Types)
  // ===============================================

  public type BucketMetadata = {
    remoteActor : Bucket.Bucket;
    canisterId : Principal;
  };


   public type GetStorageResponse = {
    bucketMetadata: BucketMetadata;
    uploadParameters: Types.UploadResponse;
  };
  

  // ===============================================
  // 4. Tipo de Estado (State Type)
  // ===============================================

  public type FileStorage = {
    index : Map.Map<Int, StorageLocation>;
    buckets : Map.Map<Principal, BucketMetadata>
  };

  // ===============================================
  // 5. Funciones Privadas
  // ===============================================


  func newBucket(callback: Types.CallbackUploadDone) : async BucketMetadata {
    Prim.cyclesAdd<system>(2_000_000_000_000); // TODO cambiar a Nueva sintaxis
    let newBucket = await Bucket.Bucket(callback);
    let canisterId = Principal.fromActor(newBucket);
    { canisterId; remoteActor = newBucket };
  };

  // ===============================================
  // 5. Funciones Publicas
  // ===============================================
  
  public func init(): FileStorage {
   { 
    index = Map.new<FileId, StorageLocation>();
    buckets =  Map.new<Principal, BucketMetadata>();
   }
  };

  public func getStorageFor(s : FileStorage, size : Nat, caller : Principal, callback: Types.CallbackUploadDone) : async GetStorageResponse {
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
      case null { await newBucket(callback) };
      case (?best) { best.bucket };
    };
    ignore Map.put<Principal, BucketMetadata>(s.buckets, phash, storage.canisterId, storage);

    let uploadParameters = await storage.remoteActor.uploadRequest(caller, size);
    {bucketMetadata  = storage; uploadParameters };

  };

  public func indexFile(s: FileStorage, id: Int, newFileMetadata: StorageLocation): () {
    ignore Map.put<Int, StorageLocation>(s.index, ihash, id, newFileMetadata)
  };

  public func isBucketCanister(s: FileStorage, p: Principal): Bool {
    Map.has<Principal, BucketMetadata>(s.buckets , phash, p)
  }

  
};

  