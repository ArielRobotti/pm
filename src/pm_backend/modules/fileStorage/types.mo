module {
  // ===============================================
  // 1. Tipos de Utilidad / Base (Base Types)
  // ===============================================

  public type FileId = Int;

  public type StorageLocation = {
    canisterId : Principal;
    internalId : Int;
  };

  public type FileMetadata = {
    owner : Principal;
    id : Int;
    authorizedReaders : [Principal];
    chunks_qty : Nat;
    total_length : Nat;
  };

  public type TempFile = FileMetadata and {
    chunks : [var Blob];
  };

  public type File = FileMetadata and {
    chunks : [Blob];
  };

  public type CallbackUploadDone = shared ({ internalId : Int }) -> async Int;


  // ===============================================
  // Data structures
  // ===============================================

  public type BucketSettings = {
    optMaxSize: ?Nat;
    optAdmins: ?[Principal];
    optChunkSize: ?Nat;

  };

  public type BucketSettingsDefinite = {
    maxSize: Nat;
    externalAdmins: [Principal];
    chunkSize: Nat;

  };

  // ===============================================
  // 3. Tipos de Request/Response
  // ===============================================

  public type UploadResponse = {
    id : FileId;
    chunksQty : Nat;
    chunkSize : Nat;
  };

  public func checkFileIntegrity(f : TempFile) : Bool {
    var byteCounter = 0;
    for (chunk in f.chunks.vals()) {
      byteCounter += chunk.size();
    };
    byteCounter == f.total_length;
  };

};
