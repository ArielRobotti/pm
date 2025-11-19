import { now } "mo:base/Time";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import { ihash; phash } "mo:map/Map";
import Buffer "mo:base/Buffer";
import { print } "mo:base/Debug";

module {

  //////////////////// Types ////////////////////

  public type UID = Int; //Date of creation

  public type State = {
    userWorkspaces: Map.Map<Principal, [UID]>;
    workspaces: Map.Map<Int, Workspace>;
    projects: Map.Map<Int, Project>;
  };

  public type Entity = {
    #Workspace: UID;
    #Project: UID;
    #Area: [UID]
  };
  public type EntityEditableData = {
    name : Text;
    description : Text;
    details: Text;
    coverImage: ?Blob;
    logo: ?Blob;
  };

  public type OptEntityEditableData = {
    name : ?Text;
    description : ?Text;
    details: ?Text;
    coverImage: ?Blob;
    logo: ?Blob;
  };

  public type EntityMetadata = EntityEditableData and {
    id : UID;
  };

  let nullEntity = {
    name : Text = "";
    description : Text = "";
    details: Text = "";
    coverImage: ?Blob = null;
    logo: ?Blob = null;
    admins: [Principal] = [];
    members : [Principal] = [];
    projectIds : [UID] = [];
    areas : [Area] = [];
    subareas : [Area] = [];
    tasks: [UID] = [];
    tags : [Text] = [];
    assignedUsers : [Principal] = [];
    status = #Todo;
    client = null;
  };


  public type Workspace = EntityMetadata and {
    owner : Principal;
    admins: [Principal];
    members : [Principal];
    projectIds : [UID];
  };

  public type Project = EntityMetadata and {
    id: UID;
    client: ?UID; 
    projectOwner : Principal;
    members : [Principal];
    workspace: UID; // vinculo bidireccional necesario?
    areas : [Area];
  };

  public type Area = EntityMetadata and {
    creator : Principal;
    members : [Principal];
    tasks : [UID];
    subareas : [Area];
  };

  public type ChangeRecord = {
    date : Int;
    user : Principal;
  };

  public type TastStatus = {
    #Todo : ChangeRecord;
    #InProgress : ChangeRecord;
    #Review: ChangeRecord;
    #Done : ChangeRecord;
    #Custom : { customStatus : Text; change : ChangeRecord };
  };

  public type Task = EntityMetadata and {
    tags : [Text];
    status : TastStatus;
    deadline: Int;
    assignedUsers : [Principal];
  };

  public func init(): State {
    {
      userWorkspaces = Map.new<Principal, [UID]>();
      workspaces = Map.new<Int, Workspace>();
      projects = Map.new<Int, Project>();
    }
  };

  //////////////////////////////// Services ///////////////////////////////////

  public func createWorkspace({state: State; name: Text; description: Text; owner: Principal}): { #Ok: Workspace; #Err: Text } {
    let id = now();

    let newWorkspace: Workspace = {
      nullEntity with
      id;
      owner;
      members = [owner];
      admins = [owner];
      name;
      description;
    };

    ignore Map.put<Int, Workspace>(state.workspaces, ihash, id, newWorkspace);
    let currentUserWorkspaces = switch(Map.get<Principal, [UID]>(state.userWorkspaces, phash, owner)) {
      case null [];
      case ( ?currentUserWorkspaces ) { currentUserWorkspaces }
    };
    let updatedUserWorkspaces = Array.tabulate<UID>(
      currentUserWorkspaces.size() + 1,
      func i = if(i == 0) { id } else { currentUserWorkspaces[ i - 1: Nat] }
    );
    ignore Map.put<Principal, [UID]>(state.userWorkspaces, phash, owner, updatedUserWorkspaces);
    #Ok(newWorkspace)
  };

  func updateData(data: EntityEditableData, optData: OptEntityEditableData) : EntityEditableData {
    let name = switch (optData.name) {case null data.name; case (?name) name};
    let description = switch (optData.description) {case null data.description; case (?description) description};
    let details = switch (optData.details) {case null data.details; case (?details) details};
    let coverImage = switch (optData.coverImage) {case null data.coverImage; case (?coverImage) ?coverImage};
    let logo = switch (optData.logo) {case null data.logo; case (?logo) ?logo};
    {name; description; details; coverImage; logo;}
  };
  
  public func editEntity(s: State, caller: Principal, entity: Entity, data: OptEntityEditableData): {#Ok; #Err: Text} {
    
    switch entity{
      case (#Workspace(id)) {
        switch (Map.get<UID, Workspace>(s.workspaces, ihash, id)){
          case null { #Err("Workspace not found") };
          case ( ?workspace ) {
            if (not inArray<Principal>(workspace.admins, caller, Principal.equal)){ 
              return #Err("Caller is not an admin")
            } else {
              let {name; description; details; coverImage; logo; } = updateData(workspace, data);
              ignore Map.put<UID, Workspace>(s.workspaces, ihash, id, {workspace with name; description; details; coverImage; logo;});
              return #Ok
            }
          }
        }
      };
      case (#Project(id)) {
        switch (Map.get<UID, Project>(s.projects, ihash, id)){
          case null { #Err("Project not found") };
          case ( ?project ) {
            if (caller != project.projectOwner){ 
              return #Err("Caller is not project owner")
            } else {
              let {name; description; details; coverImage; logo; } = updateData(project, data);
              ignore Map.put<UID, Project>(s.projects, ihash, id, {project with name; description; details; coverImage; logo;});
              return #Ok
            }
          }
        }
      };
      case (#Area(path)) {
        if(path.size() < 2) {
          return #Err("Incorrect path")
        };
        switch(Map.get<UID, Project>(s.projects, ihash, path[0])){
          case null { return #Err("Project not found")};
          case (?project){
            let areasBuffer = Buffer.fromArray<Area>([]);
            for (area in project.areas.vals()){
              if (area.id == path[1]){
                areasBuffer.add(updateArea(area, Array.subArray(path, 2, (path.size() -2: Nat)), data));
                // print(debug_show(area));
              } else {
                areasBuffer.add(area)
              }
            };
            let areas = Buffer.toArray(areasBuffer);
            ignore Map.put<UID, Project>(s.projects, ihash, path[0], {project with areas});
            #Ok
          }
        }
      };
      case _ { #Ok }
    }
  };

  func updateArea(root: Area, path: [UID], newData: OptEntityEditableData): Area {
    print(debug_show(path));
    if(path.size() == 0){ // Caso base recursividad
      let {name; description; details; coverImage; logo} = updateData(root, newData);
      return {root with name; description; details; coverImage; logo;}
    };
    let areasBuffer = Buffer.fromArray<Area>([]);

    for (area in root.subareas.vals()){
      if(area.id != path[0]) { 
        areasBuffer.add(area)
      } else {
        areasBuffer.add(updateArea(area, Array.subArray(path, 1, path.size() -1 : Nat), newData))
      }
    };
    {root with subareas = Buffer.toArray<Area>(areasBuffer)}
  };


  /////////////////////////////////// Geters ////////////////////////////////////

  public func getUserWorkspaces(state: State, caller: Principal): [UID]{
    switch (Map.get<Principal, [UID]>(state.userWorkspaces, phash, caller)){
      case null { [] };
      case (?uids) {uids}
    }
  };

  //////////////////////////// Auxiliar functions  //////////////////////////////

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
  //////////////////////////////////////////////////////////////////////////////

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
              func (a: Int, b: Int) = a == b
            )
          );
          #Ok(members)
        }
      }
    }
  };

  public func createProject(s: State, wsid: Int, projectOwner: Principal, name: Text, description: Text): {#Ok: Project; #Err}{
    switch (getWorkspace(s, wsid, projectOwner)) {
      case (#Err(_)) { #Err };
      case (#Ok(ws)){
        //User can create project?
        let id = now();

        let newProject: Project = {
          nullEntity with
          name;
          description;
          workspace = wsid;
          id;
          projectOwner;
          members : [Principal] = [projectOwner];
        };
        ignore Map.put<UID, Project>(s.projects, ihash, id, newProject);
        let updateProjectIds = addIfNotInclude<Int>(ws.projectIds, id, func (a: UID, b: UID) = a == b);
        ignore Map.put<UID, Workspace>(s.workspaces, ihash, wsid, { ws with projectIds = updateProjectIds});
        #Ok(newProject)
      }
    }
  };

  public func getProject(state: State, id: UID, caller: Principal): {#Ok: Project; #Err: Text}{
    switch (Map.get<Int, Project>(state.projects, ihash, id)){
      case null { #Err("ProjectNotFound") };
      case (?project) {
        if (not inArray<Principal>(project.members, caller, Principal.equal)){
          #Err("AccessDenied")
        } else {
          #Ok(project)
        }
      }
    }
  };

  func insertArea(areas: [Area], new: Area, path: [UID]): [Area] {
    if(path.size() == 0){
      Array.tabulate<Area>( 
        areas.size() + 1,  
        func i = if( i == 0) {new} else {areas[i -1: Nat]}
      );
    } else {
      let areasBuffer = Buffer.fromArray<Area>([]);
      for (area in areas.vals()){
        if(area.id == path[0]){
          areasBuffer.add(
            {area with subareas = insertArea(area.subareas, new, Array.subArray<UID>(path, 1, (path.size() - 1:Nat)))}
          )
        } else {
          areasBuffer.add(area)
        }

      };
      return Buffer.toArray(areasBuffer)
    }
  };

  public func createArea(s: State, prid: UID, path: [UID], creator: Principal, name: Text, description: Text): {#Ok: Area; #Err} {
    switch(Map.get<Int, Project>(s.projects, ihash, prid)){
      case null { #Err };
      case (?project) {
        if (not inArray<Principal>(project.members, creator, Principal.equal)){
          #Err
        } else {
          let id = now();
          let newArea: Area = {nullEntity with name; description; id; creator};
          let updatedAreas = insertArea(project.areas, newArea, path);
          ignore Map.put<UID, Project>(s.projects, ihash, prid, { project with areas = updatedAreas});

          #Ok(newArea)
        }
      }
    }
  };

};
