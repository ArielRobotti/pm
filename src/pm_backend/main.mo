import User "./modules/User";
import Workspace "./modules/Workspace";
import FileStorage "./modules/fileStorage/FileStorage";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import Set "mo:map/Set";
import { now } "mo:base/Time";

shared ({caller}) persistent actor class() {

  type UID = Workspace.UID;

  let users = User.init(caller);
  let workspaces = Workspace.init();
  // let fileStorage = FileStorage.init();

  //// Admin functions test ///

  public shared ({ caller }) func testUploadFileRequest(size: Nat): async FileStorage.GetStorageResponse {
    assert(User.isUser(users, caller));
    await FileStorage.getStorageFor(workspaces.fileStorage, size, caller, callback)
  };

  public shared ({ caller }) func getFilestorageInfo(): async [(Int, FileStorage.StorageLocation)] {
    // assert (User.isAdmin(users, caller));
    Map.toArray<Int, FileStorage.StorageLocation>(workspaces.fileStorage.index)
  };

  public shared ({ caller }) func getBucketsMetadata(): async [(Principal, FileStorage.BucketMetadata)]{
    Map.toArray<Principal, FileStorage.BucketMetadata>(workspaces.fileStorage.buckets)
  };


  public shared ({caller})func callback({internalId: Int}): async Int {
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

  public shared ({ caller }) func login() : async User.LoginResponse {
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

  public shared ({ caller }) func editProject(data: Workspace.OptEntityEditableData, id: UID): async { #Ok; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("Caller is not an user")
    };
    Workspace.editEntity(workspaces, caller, #Project(id), data)
  };

  public shared ({ caller }) func editArea(data: Workspace.OptEntityEditableData, path: [UID]): async { #Ok; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("Caller is not an user")
    };
    Workspace.editEntity(workspaces, caller, #Area(path), data)
  };

  public shared ({ caller }) func getMyWorkspaces(): async [UID]{
    Workspace.getUserWorkspaces(workspaces, caller)
  };

  public shared ({ caller }) func getWorkspace(id: UID): async {#Ok: Workspace.Workspace; #Err: Text}{
    Workspace.getWorkspace(workspaces, id, caller)
  };

  public shared ({ caller }) func addMemberToWorkspace(wsid: UID, newMember: Principal): async {#Ok: [Principal]; #Err: Text } {
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    Workspace.addMember(workspaces, #Workspace(wsid), caller, newMember)
  };

  /// Projects ///

  public shared ({ caller }) func createProject({wsid: UID; name: Text; description: Text}): async {#Ok: Workspace.Project; #Err} {
    if(not User.isUser(users, caller)){
      return #Err
    };
    Workspace.createProject(workspaces, wsid, caller, name, description)
  };

  public shared ({ caller }) func getProject(id: UID): async {#Ok: Workspace.Project; #Err: Text}{
    Workspace.getProject(workspaces, id, caller)
  };

  public shared ({ caller }) func addMemberToProject({prid: UID;  newMember: Principal}): async {#Ok: [Principal]; #Err: Text }{
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    Workspace.addMember(workspaces, #Project(prid), caller, newMember)
  };

  /// Areas ///

  public shared ({ caller }) func createArea({prid: UID; path: [UID]; name: Text; description: Text}): async {#Ok: Workspace.Area; #Err} {
    Workspace.createArea(workspaces, prid, path, caller, name, description)
  };

  public shared ({ caller }) func comment({entity: Workspace.Entity; msg: Text; path: [Int]}): async Workspace.PushResult{
    Workspace.pushComment(workspaces, entity, path, msg, caller)
  };



};
