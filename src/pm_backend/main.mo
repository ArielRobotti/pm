import User "./modules/User";
import Workspace "./modules/Workspace";
import Principal "mo:base/Principal";

persistent actor {

  type UID = Workspace.UID;

  let users = User.init();
  let workspaces = Workspace.init();


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
    Workspace.addMember(workspaces, wsid, caller, newMember)
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

  /// Areas ///

  public shared ({ caller }) func createArea({prid: UID; path: [UID]; name: Text; description: Text}): async {#Ok: Workspace.Area; #Err} {
    Workspace.createArea(workspaces, prid, path, caller, name, description)
  };




};
