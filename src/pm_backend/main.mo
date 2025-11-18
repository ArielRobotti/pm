import User "./modules/User";
import Workspace "./modules/Workspace";
import Principal "mo:base/Principal";

persistent actor {

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

  public shared ({ caller }) func createWorkspace({name: Text; description: Text}): async {#Ok: Workspace.Workspace; #Err: Text}{
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    // Politicas de permisos segun planes de pago
    Workspace.createWorkspace({state = workspaces; name; description; owner = caller})
  };

  public shared ({ caller }) func getMyWorkspaces(): async [Workspace.UID]{
    Workspace.getUserWorkspaces(workspaces, caller)
  };

  public shared ({ caller }) func getWorkspace(id: Workspace.UID): async {#Ok: Workspace.Workspace; #Err: Text}{
    Workspace.getWorkspace(workspaces, id, caller)
  };

  public shared ({ caller }) func addMemberToWorkspace(wsid: Workspace.UID, newMember: Principal): async {#Ok: [Principal]; #Err: Text } {
    if(not User.isUser(users, caller)){
      return #Err("UserNotFound")
    };
    Workspace.addMember(workspaces, wsid, caller, newMember)
  };


};
