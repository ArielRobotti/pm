import User "./modules/User";
import Workspace "./modules/Workspace";
import FileStorage "./modules/fileStorage/FileStorage";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import Set "mo:map/Set";
import { now } "mo:base/Time";
import { print } "mo:base/Debug";

shared ({caller = SUPER_ADMIN}) persistent actor class() = this {

  type UID = Workspace.UID;

  let users = User.init(SUPER_ADMIN);
  let workspaces = Workspace.init();

  //// Admin functions test ///

  public shared ({ caller }) func testUploadFileRequest(size: Nat): async FileStorage.GetStorageResponse {
    assert(User.isUser(users, caller));
    let adminsBucket = [SUPER_ADMIN, Principal.fromActor(this)];
    await FileStorage.getStorageFor(workspaces.fileStorage, adminsBucket, size, caller, callback)
  };

  public shared ({ caller }) func getFilestorageInfo(): async [(Int, FileStorage.StorageLocation)] {
    // assert (User.isAdmin(users, caller));
    Map.toArray<Int, FileStorage.StorageLocation>(workspaces.fileStorage.index)
  };

  public shared ({ caller }) func getBucketsMetadata(): async [(Principal, FileStorage.BucketMetadata)]{
    Map.toArray<Principal, FileStorage.BucketMetadata>(workspaces.fileStorage.buckets)
  };

  public shared ({ caller }) func getBucketCanisterStatus(canisterId: Principal): async FileStorage.CanisterStatusResult {

    await FileStorage.canisterStatus(canisterId)
  };

  public shared ({caller})func callback({internalId: Int}): async Int {
    print(debug_show(caller) # "llamando a PM");
    assert(FileStorage.isBucketCanister(workspaces.fileStorage, caller));
    let id = now();
    FileStorage.indexFile(workspaces.fileStorage, id, {canisterId = caller; internalId});
    let remoteBucket: FileStorage.Bucket = actor(Principal.toText(caller));
    ignore remoteBucket.updateSettings({
      optAdmins = ?Set.toArray(users.admins);
      optChunkSize = null;
      optMaxSize = null;
    });
    id
  };

  public shared ({ caller }) func signUp(name : Text) : async User.SignUpResponse {
    assert (not Principal.isAnonymous(caller));
    User.signUp(users, caller, name);
  };

  public shared query ({ caller }) func login() : async User.LoginResponse {
    assert (not Principal.isAnonymous(caller));
    User.login(users, caller);
  };

  //// Workspaces ///

  public shared ({ caller }) func createWorkspace({name: Text; description: Text}): async {#Ok: Workspace.Workspace; #Err: Text}{
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    // Politicas de permisos segun planes de pago
    Workspace.createWorkspace({state = workspaces; name; description; owner = caller})
  };

  public shared ({ caller }) func editWorkspace(data: Workspace.OptEntityEditableData, id: UID): async { #Ok; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("Caller is not an user")
    };
    Workspace.editEntity(workspaces, caller, #Workspace(id), data)
  };

  public shared ({ caller }) func editArea(data: Workspace.OptEntityEditableData, path: [UID]): async { #Ok; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("Caller is not an user")
    };
    Workspace.editEntity(workspaces, caller, #Area(path), data)
  };

  public shared query ({ caller }) func getMyWorkspaces(): async [UID]{
    Workspace.getUserWorkspaces(workspaces, caller)
  };

  public shared query ({ caller }) func getWorkspace(id: UID): async {#Ok: Workspace.Workspace; #Err: Text}{
    Workspace.getWorkspace(workspaces, id, caller)
  };

  public shared ({ caller }) func addMemberToWorkspace(wsid: UID, newMember: Principal): async {#Ok: [Principal]; #Err: Text } {
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    Workspace.addMember(workspaces, #Workspace(wsid), caller, newMember)
  };

  /// CRUD Projects ///

  public shared ({ caller }) func createProject({wsid: UID; name: Text; description: Text}): async {#Ok: Workspace.Project; #Err} {
    if(not User.isUser(users, caller)){
      return #Err
    };
    Workspace.createProject(workspaces, wsid, caller, name, description)
  };
  
  public shared query ({ caller }) func getProject(id: UID): async {#Ok: Workspace.Project; #Err: Text}{
    Workspace.getProject(workspaces, id, caller)
  };

  public shared ({ caller }) func editProject(data: Workspace.OptEntityEditableData, id: UID): async { #Ok; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("Caller is not an user")
    };
    Workspace.editEntity(workspaces, caller, #Project(id), data)
  };

  public shared ({ caller }) func addMemberToProject({prid: UID;  newMember: Principal}): async {#Ok: [Principal]; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    Workspace.addMember(workspaces, #Project(prid), caller, newMember)
  };

  public shared ({ caller }) func archiveProject(): async (){
    
  };


  ///// Areas /////

  public shared ({ caller }) func createArea({prid: UID; path: [UID]; name: Text; description: Text}): async {#Ok: Workspace.Area; #Err} {
    Workspace.createArea(workspaces, prid, path, caller, name, description)
  };

  //// CRUD Comments and reactions /////

  public shared ({ caller }) func comment({entity: Workspace.Entity; msg: Text; path: [Int]}): async Workspace.PushResult{
    Workspace.pushComment(workspaces, entity, path, msg, caller)
  };

  public shared ({ caller }) func deleteComment({entity: Workspace.Entity; path: [Int]}): async Workspace.DeleteResult {
    Workspace.deleteComment(workspaces, entity, path, caller)
  };

  public shared ({ caller }) func editComment({entity: Workspace.Entity; path: [Int]; newMsg: Text}): async Workspace.EditResult {
    Workspace.editComment(workspaces, entity, path, newMsg, caller)
  };

  public shared ({ caller }) func reactToComment({entity: Workspace.Entity; path: [Int]; reaction: ?Bool}): async Workspace.ReactResult {
    Workspace.reactToComment(workspaces, entity, path, reaction, caller)
  };

  //////////////////////////////////////


};
