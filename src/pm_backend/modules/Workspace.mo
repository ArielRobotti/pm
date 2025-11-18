import { now } "mo:base/Time";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import { ihash; phash } "mo:map/Map";

module {

  public type UID = Int; //Date of creation

  public type State = {
    userWorkspaces: Map.Map<Principal, [UID]>;
    workspaces: Map.Map<Int, Workspace>;
  };

  public type EntityMetadata = {
    id : UID;
    name : Text;
    description : Text;
    coverImage: ?Blob;
    logo: ?Blob;
  };

  public type Workspace = EntityMetadata and {
    owner : Principal;
    admins: [Principal];
    members : [Principal];
    boards : [UID];
  };

  public type Proyect = EntityMetadata and {
    id: UID;
    client: ?UID; 
    crator : Principal;
    members : [Principal];
    // workspace: UID; // vinculo bidireccional necesario?
    areas : [Area];
  };

  public type Area = EntityMetadata and {
    crator : Principal;
    members : [Principal];
    task : [UID];
    subareas : [Area];
  };

  public type ChangeRecord = {
    date : Int;
    user : Principal;
  };

  public type TastStatus = {
    #Todo : ChangeRecord;
    #Inprogress : ChangeRecord;
    #Done : ChangeRecord;
    #Custom : { staus : Text; change : ChangeRecord };
  };

  public type Task = EntityMetadata and {
    tags : Text;
    state : TastStatus;
    assignedUsers : [Principal];
  };

  /// Services

  public func init(): State {
    {
      userWorkspaces = Map.new<Principal, [UID]>();
      workspaces = Map.new<Int, Workspace>();
    }
  };
  
  public func createWorkspace({state: State; name: Text; description: Text; owner: Principal}): {#Ok: Workspace; #Err: Text } {
    let uid = now();
    let newWorkspace: Workspace = {
      admins : [Principal] = [owner];
      boards : [UID] = [];
      coverImage : ?Blob = null;
      description : Text = description;
      id : UID = uid;
      logo : ?Blob = null;
      members : [Principal] = [owner];
      name : Text = name;
      owner : Principal = owner;
    };
    ignore Map.put<Int, Workspace>(state.workspaces, ihash, uid, newWorkspace);
    let currentUserWorkspaces = switch(Map.get<Principal, [UID]>(state.userWorkspaces, phash, owner)) {
      case null [];
      case ( ?currentUserWorkspaces ) { currentUserWorkspaces }
    };
    let updatedUserWorkspaces = Array.tabulate<UID>(
      currentUserWorkspaces.size() + 1,
      func i = if(i == 0) { uid } else { currentUserWorkspaces[ i - 1: Nat] }
    );
    ignore Map.put<Principal, [UID]>(state.userWorkspaces, phash, owner, updatedUserWorkspaces);
    #Ok(newWorkspace)
  };

  public func getUserWorkspaces(state: State, caller: Principal): [UID]{
    switch (Map.get<Principal, [UID]>(state.userWorkspaces, phash, caller)){
      case null { [] };
      case (?uids) {uids}
    }
  };
  
  func addIfNotInclude<T>(a: [T], e: T, equal: (T, T ) -> Bool): [T] {
    if(not inArray<T>(a, e, equal)){
      Array.tabulate<T>(
        a.size() + 1,
        func i = if(i == 0 ) { e } else { a[i - 1: Nat]} 
      )
    } else {
      a
    }
  };

  func inArray<T>(a: [T], e: T, equal: (T, T) -> Bool): Bool{
    for (elem in a.vals()){
      if(equal(elem, e)){ return true }
    };
    false
  };

  public func getWorkspace(state: State, id: UID, caller: Principal): {#Ok: Workspace; #Err: Text}{
    switch (Map.get<Int, Workspace>(state.workspaces, ihash, id)){
      case null { #Err("WorkspaceNotFound") };
      case (?workspace) {
        if (not inArray<Principal>(workspace.members, caller, Principal.equal)){
          #Err("AccessDenied")
        } else {
          #Ok(workspace)
        }
      }
    }
  };

  public func addMember(state: State, id: UID, caller: Principal, newMember: Principal): {#Ok: [Principal]; #Err: Text } {
    switch (Map.get<Int, Workspace>(state.workspaces, ihash, id)){
      case null { #Err("WorkspaceNotFound") };
      case (?workspace) {
        if (not inArray<Principal>(workspace.admins, caller, Principal.equal)){
          #Err("ActionDenied")
        } else {
          let members = addIfNotInclude<Principal>(workspace.members, newMember, Principal.equal);
          ignore Map.put<Int, Workspace>(
            state.workspaces, 
            ihash, 
            id, 
            {workspace with members}
          );
          ignore Map.put<Principal, [UID]>(
            state.userWorkspaces, 
            phash,
            newMember,
            addIfNotInclude<Int>(
              getUserWorkspaces(state, newMember),
              id,
              func  (a: Int, b: Int) = a == b
            )
          );
          #Ok(members)
        }
      }
    }
  }



};
