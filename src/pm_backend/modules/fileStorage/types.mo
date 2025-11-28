module {

  // ===============================================
  // 0. Canister status (System)
  // ===============================================

  public type Status = {
    rts: {
      rts_callback_table_count :Nat;
      rts_callback_table_size :Nat;
      rts_collector_instructions :  Nat;
      rts_heap_size : Nat;
      rts_logical_stable_memory_size : Nat;
      rts_max_live_size : Nat;
      rts_max_stack_size :  Nat;
      rts_memory_size :  Nat;
      rts_mutator_instructions : Nat;
      rts_reclaimed : Nat;
      rts_stable_memory_size :  Nat;
      rts_total_allocation : Nat;
      rts_upgrade_instructions :  Nat;
      rts_version : Text;
    };
    canister: {
      balance: Nat;
      // stableMemorySize : Nat64;

    }
  };

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
    adminsBucket: [Principal];
    chunkSize: Nat;
    uploadDone: ?(shared {internalId: Int} -> async Int)
  };

  public type BucketStatus = {
    maxSize: Nat;
    adminsBucket: [Principal];
    chunkSize: Nat;
    currentSize: Nat;
    cycles: Nat;
    admins: [Principal];
    controllers: [Principal];
    ready: Bool;
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
