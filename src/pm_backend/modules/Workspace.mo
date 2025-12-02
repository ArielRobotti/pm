import { now } "mo:base/Time";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import Set "mo:map/Set";
import { ihash; phash } "mo:map/Map";
import Buffer "mo:base/Buffer";
import List "mo:base/List";
import { print } "mo:base/Debug";
import FileStorage "./fileStorage";
import Comments "./comments";
import Types "../types";
import Notifications "./notifications";

module {

  //////////////////// Types ////////////////////

  public type UID = Types.UID;
  public type UserResources = Types.UserResources;
  public type State = Types.State;
  public type Entity = Types.Entity;
  public type EntityEditableData = Types.EntityEditableData;
  public type OptEntityEditableData = Types.OptEntityEditableData;
  public type EntityMetadata = Types.EntityMetadata;
  public type Workspace = Types.Workspace;
  public type Project = Types.Project;
  public type Comment = Types.Comment;
  public type Area = Types.Area;
  public type ChangeRecord = Types.ChangeRecord;
  public type TastStatus = Types.TastStatus;
  public type Task = Types.Task;

  // public let anonimous = Principal.fromBlob("\04");
  // let blob: Blob = "\04";

  let nullEntity = {
    id = 0;
    name : Text = "";
    description : Text = "";
    details : Text = "";
    coverImage : ?Blob = null;
    logo : ?Blob = null;
    admins : [Principal] = [];
    members : [Principal] = [];
    projectIds : [UID] = [];
    areas : [Area] = [];
    subareas : [Area] = [];
    tasks : [UID] = [];
    tags : [Text] = [];
    assignedUsers : [Principal] = [];
    status = #Todo;
    client = null;
  };

  func callback(pm: Principal): FileStorage.CallbackUploadDone {
    // Si cambia la firma de onFileLoadedCallback en PM reflejar ese cambio tambien acá (Posible error silencioso)
    let PM: actor {onFileLoadedCallback: FileStorage.CallbackUploadDone } = actor(Principal.toText(pm));
    PM.onFileLoadedCallback
  };

  public func init({bucketAdmins: [Principal]; pm: Principal}) : State {
    {
      userResources = Map.new<Principal, UserResources>();
      userNotifications = Notifications.init();
      workspaces = Map.new<Int, Workspace>();
      projects = Map.new<Int, Project>();
      fileStorage = FileStorage.init({bucketAdmins});
    };
  };

  public type PushCommentResult = Comments.PushResult;
  public type DeleteResult = Comments.DeleteResult;
  public type ReactResult = Comments.ReactResult;
  public type EditResult = Comments.EditResult;

  //////////////////////////////// Services ///////////////////////////////////

  public func createWorkspace({ state : State; name : Text; description : Text; owner : Principal }) : { #Ok : Workspace; #Err : Text } {
    let id = now();
    let newWorkspace : Workspace = {
      nullEntity with
      id;
      owner;
      members = [owner];
      admins = [owner];
      name;
      description;
    };

    ignore Map.put<Int, Workspace>(state.workspaces, ihash, id, newWorkspace);
    
    let userResources: UserResources = switch(Map.get<Principal, UserResources>(state.userResources, phash, owner)){
      case null { {workspaces = []; projects = []} };
      case ( ?v ) { v }
    };

    ignore Map.put<Principal, UserResources>(
      state.userResources, 
      phash, 
      owner, 
      {userResources with workspaces = addIfNotInclude<UID>(userResources.workspaces, id, func (a: UID, b: UID) = a == b)}
    );

    #Ok(newWorkspace);
  };

  func updateData(data : EntityEditableData, optData : OptEntityEditableData) : EntityEditableData {
    let name = switch (optData.name) { case null data.name; case (?v) v };
    let description = switch (optData.description) { case null data.description; case (?v) v };
    let details = switch (optData.details) { case null data.details; case (?v) v };
    let coverImage = switch (optData.coverImage) { case null data.coverImage; case (v) v };
    let logo = switch (optData.logo) { case null data.logo; case (v) v };
    { name; description; details; coverImage; logo };
  };

  public func editEntity(s : State, caller : Principal, entity : Entity, data : OptEntityEditableData) : {
    #Ok;
    #Err : Text;
  } {

    switch entity {
      case (#Workspace(id)) {
        switch (Map.get<UID, Workspace>(s.workspaces, ihash, id)) {
          case null { #Err("Workspace not found") };
          case (?workspace) {
            if (not inArray<Principal>(workspace.admins, caller, Principal.equal)) {
              return #Err("Caller is not an admin");
            } else {
              let { name; description; details; coverImage; logo } = updateData(workspace, data);
              ignore Map.put<UID, Workspace>(s.workspaces, ihash, id, { workspace with name; description; details; coverImage; logo });
              return #Ok;
            };
          };
        };
      };
      case (#Project(id)) {
        switch (Map.get<UID, Project>(s.projects, ihash, id)) {
          case null { #Err("Project not found") };
          case (?project) {
            if (caller != project.projectOwner) {
              return #Err("Caller is not project owner");
            } else {
              let { name; description; details; coverImage; logo } = updateData(project, data);
              ignore Map.put<UID, Project>(s.projects, ihash, id, { project with name; description; details; coverImage; logo });
              return #Ok;
            };
          };
        };
      };
      case (#Area(path)) {
        if (path.size() < 2) {
          return #Err("Incorrect path");
        };
        switch (Map.get<UID, Project>(s.projects, ihash, path[0])) {
          case null { return #Err("Project not found") };
          case (?project) {
            let areasBuffer = Buffer.fromArray<Area>([]);
            for (area in project.areas.vals()) {
              if (area.id == path[1]) {
                areasBuffer.add(updateArea(area, Array.subArray(path, 2, (path.size() -2 : Nat)), data));
                // print(debug_show(area));
              } else {
                areasBuffer.add(area);
              };
            };
            let areas = Buffer.toArray(areasBuffer);
            ignore Map.put<UID, Project>(s.projects, ihash, path[0], { project with areas });
            #Ok;
          };
        };
      };
      case _ { #Ok };
    };
  };

  func updateArea(root : Area, path : [UID], newData : OptEntityEditableData) : Area {
    print(debug_show (path));
    if (path.size() == 0) {
      // Caso base recursividad
      let { name; description; details; coverImage; logo } = updateData(root, newData);
      return { root with name; description; details; coverImage; logo };
    };
    let areasBuffer = Buffer.fromArray<Area>([]);

    for (area in root.subareas.vals()) {
      if (area.id != path[0]) {
        areasBuffer.add(area);
      } else {
        areasBuffer.add(updateArea(area, Array.subArray(path, 1, path.size() -1 : Nat), newData));
      };
    };
    { root with subareas = Buffer.toArray<Area>(areasBuffer) };
  };

  /////////////////////////////////// Geters ////////////////////////////////////

  public func getUserWorkspaces(state : State, caller : Principal) : [Types.EntityCard] {
    switch (Map.get<Principal, UserResources>(state.userResources, phash, caller)){
      case null [];
      case (?resources) {
        var result = List.nil<Types.EntityCard>();
        for (id in resources.workspaces.vals()){
          switch (Map.get<UID, Workspace>(state.workspaces, ihash, id)){
            case ( ?ws ) {
              result := List.push<Types.EntityCard>(ws, result)
            };
            case null {}
          }
        };
        List.toArray(result)
        
      }
    }
  };

  public func getUserProjects(state : State, caller : Principal) : [UID] {
    switch (Map.get<Principal, UserResources>(state.userResources, phash, caller)){
      case null [];
      case (?resources) {resources.projects}
    }
  };

  //////////////////////////// Auxiliar functions  //////////////////////////////

  func addIfNotInclude<T>(a : [T], e : T, equal : (T, T) -> Bool) : [T] {
    if (not inArray<T>(a, e, equal)) {
      Array.tabulate<T>(
        a.size() + 1,
        func i = if (i == 0) { e } else { a[i - 1 : Nat] },
      );
    } else {
      a;
    };
  };

  func inArray<T>(a : [T], e : T, equal : (T, T) -> Bool) : Bool {
    for (elem in a.vals()) {
      if (equal(elem, e)) { return true };
    };
    false;
  };

  func insertArea(areas : [Area], new : Area, path : [UID]) : [Area] {
    if (path.size() == 0) {
      Array.tabulate<Area>(
        areas.size() + 1,
        func i = if (i == 0) { new } else { areas[i - 1 : Nat] },
      );
    } else {
      let areasBuffer = Buffer.fromArray<Area>([]);
      for (area in areas.vals()) {
        if (area.id == path[0]) {
          areasBuffer.add({
            area with subareas = insertArea(area.subareas, new, Array.subArray<UID>(path, 1, (path.size() - 1 : Nat)))
          });
        } else {
          areasBuffer.add(area);
        };
      };
      return Buffer.toArray(areasBuffer);
    };
  };

  func isWorkspaceAdmin(s : State, wsid : UID, u : Principal) : Bool {
    switch (Map.get<UID, Workspace>(s.workspaces, ihash, wsid)) {
      case null { false };
      case (?ws) { inArray<Principal>(ws.admins, u, Principal.equal) };
    };
  };

  func iequal(a: Int, b: Int): Bool { a == b};
  //////////////////////////////////////////////////////////////////////////////

  public func getWorkspace(state : State, id : UID, caller : Principal) : {
    #Ok : Workspace;
    #Err : Text;
  } {
    switch (Map.get<Int, Workspace>(state.workspaces, ihash, id)) {
      case null { #Err("WorkspaceNotFound") };
      case (?workspace) {
        if (not inArray<Principal>(workspace.members, caller, Principal.equal)) {
          #Err("AccessDenied");
        } else {
          #Ok(workspace);
        };
      };
    };
  };

  public func addMember(s: State, e: Entity, caller: Principal, newMember: Principal): {#Ok: [Principal]; #Err: Text}{
    switch e {
      case ( #Workspace(id) ) {
        switch(Map.get<Int, Workspace>(s.workspaces, ihash, id)) {
          case null { return #Err("WorkspaceNotFound")};
          case ( ?ws ) {
            if (not inArray<Principal>(ws.admins, caller, Principal.equal)) {
              #Err("ActionDenied");
            } else {
              let members = addIfNotInclude<Principal>(ws.members, newMember, Principal.equal);
              // Push notification to newMember
              ignore Map.put<Int, Workspace>(
                s.workspaces,
                ihash,
                id,
                { ws with members },
              );
              let userResources: UserResources = switch(Map.get<Principal, UserResources>(s.userResources, phash, newMember)){
                case null { {workspaces = []; projects = []} };
                case ( ?r ) { r }
              };
              ignore Map.put<Principal, UserResources>(
                s.userResources, 
                phash,
                newMember,
                {userResources with workspaces = addIfNotInclude(userResources.workspaces, id, iequal)} 
              );

              #Ok(members);
            }
          } 
        }
      };
      case ( #Project(id) ) {
        switch (Map.get<UID, Project>(s.projects, ihash,id )) {
          case null { return #Err("ProjectNotFound")};
          case ( ?pr ) {
            if(pr.projectOwner != caller) {
              return #Err("ActionDenied")
            } else {

              let parentWs: Workspace = switch(Map.get<UID, Workspace>(s.workspaces, ihash, pr.workspace)){
                case null {return #Err("Error 001"); {nullEntity with owner = Principal.fromBlob("\04")} };
                case (?ws) { ws }
              };

              let projectMembers = addIfNotInclude<Principal>(pr.members, newMember, Principal.equal);
              let workspaceMembers = addIfNotInclude<Principal>(parentWs.members, newMember, Principal.equal);
              ignore Map.put<UID, Workspace>(s.workspaces, ihash, pr.workspace, {parentWs with members = workspaceMembers });
              ignore Map.put<UID, Project>(s.projects, ihash, id, {pr with members = projectMembers });

              let userResources: UserResources = switch(Map.get<Principal, UserResources>(s.userResources, phash, newMember)){
                case null { {workspaces = []; projects = []}};
                case ( ?r ) { r }; 
              };
              ignore Map.put<Principal, UserResources>(
                s.userResources, 
                phash, 
                newMember,
                {
                  workspaces = addIfNotInclude<Int>(userResources.workspaces, pr.workspace, iequal);
                  projects = addIfNotInclude<Int>(userResources.projects, pr.id, iequal);
                }
              );
              #Ok(projectMembers)
            }
          }
        }

      };
      case ( #Area(_path) ){
        //TODO
        #Ok([]);
      };
      case _ { 
        #Ok([]);
      };
    }
  };

  public func createProject(s : State, wsid : Int, projectOwner : Principal, name : Text, description : Text) : {
    #Ok : Project;
    #Err;
  } {
    switch (getWorkspace(s, wsid, projectOwner)) {
      case (#Err(_)) { #Err };
      case (#Ok(ws)) {
        //User can create project?
        let id = now();

        let newProject : Project = {
          nullEntity with
          name;
          description;
          workspace = wsid;
          id;
          projectOwner;
          members : [Principal] = [projectOwner];
          commentBox = Comments.newBox({depthLimit = 3});
        };
        ignore Map.put<UID, Project>(s.projects, ihash, id, newProject);
        let updateProjectIds = addIfNotInclude<Int>(ws.projectIds, id, func(a : UID, b : UID) = a == b);
        ignore Map.put<UID, Workspace>(s.workspaces, ihash, wsid, { ws with projectIds = updateProjectIds });
        #Ok(newProject);
      };
    };
  };

  public func getProjectsCardFrom(s: State, caller: Principal, wsid: UID ): [Types.EntityCard] {
    switch (getWorkspace(s, wsid, caller)) {
      case (#Err(_)) { [] };
      case (#Ok(ws)) {
        var result = List.nil<Types.EntityCard>();
        for(id in ws.projectIds.vals()){
          switch(Map.get<UID, Project>(s.projects, ihash, id)){
            case ( ?p ) { 
              result := List.push<Types.EntityCard>(p, result)
             };
            case null { }
          }
        };
        List.toArray(result);
      };
    };
  };

  public func getProject(state : State, id : UID, caller : Principal) : {
    #Ok : Project;
    #Err : Text;
  } {
    switch (Map.get<Int, Project>(state.projects, ihash, id)) {
      case null { #Err("ProjectNotFound") };
      case (?project) {
        if (not inArray<Principal>(project.members, caller, Principal.equal) and not isWorkspaceAdmin(state, project.workspace, caller)) {
          #Err("AccessDenied");
        } else {
          #Ok(project);
        };
      };
    };
  };

  func flattenAndDeduplicate<T>(m: [[T]], hashEqFn: (T -> Nat32, (T, T) -> Bool)): [T]{
    let set = Set.new<T>();
    for (array in m.vals()){
      for (e in array.vals()) {
        ignore Set.put<T>(set, hashEqFn, e);
      }
    };
    Set.toArray(set)
  };

  public func getMembersFrom(s: State, e: Entity): [Principal]{
    switch e {
      case ( #Workspace(id) ) {
        switch (Map.get<UID, Workspace>(s.workspaces, ihash, id)) {
          case null { [] };
          case ( ?ws ) {
            flattenAndDeduplicate<Principal>([[ws.owner], ws.admins, ws.members], phash)
          };
        };
      };
      case ( #Project(id) ) { 
        switch (Map.get<UID, Project>(s.projects, ihash, id)) {
          case null { [] };
          case ( ?ws ) {
            flattenAndDeduplicate<Principal>([[ws.projectOwner], ws.members], phash)
          };
        }; 
      };
      case ( #Area(_path) ) {
        // TODO
        []
      };
      case _ { [] };
      
    };
    // []
  };


  public func createArea(s : State, prid : UID, path : [UID], creator : Principal, name : Text, description : Text) : {
    #Ok : Area;
    #Err;
  } {
    switch (Map.get<Int, Project>(s.projects, ihash, prid)) {
      case null { #Err };
      case (?project) {
        if (not inArray<Principal>(project.members, creator, Principal.equal)) {
          #Err;
        } else {
          let id = now();
          let newArea : Area = {
            nullEntity with name;
            description;
            id;
            creator;
          };
          let updatedAreas = insertArea(project.areas, newArea, path);
          ignore Map.put<UID, Project>(s.projects, ihash, prid, { project with areas = updatedAreas });

          #Ok(newArea);
        };
      };
    };
  };

  public func pushComment(s: State, input: {entity: Entity; path: [Int]; msg: Text}, caller: Principal): PushCommentResult { 
    Comments.pushComment(s, input, caller)
  };

  public func deleteComment(s: State, e: Entity, path: [Int], caller: Principal): DeleteResult {
    Comments.deleteComment(s, e, path, caller)
  };

  public func editComment(s: State, e: Entity, path: [Int], newMsg: Text, caller: Principal): EditResult {
    Comments.editComment(s, e, path, newMsg, caller)
  };

  public func reactToComment(s: State, e: Entity, path: [Int], reaction: ?Bool, caller: Principal): ReactResult {
    Comments.reactToComment(s, e, path, reaction, caller)
  };
   
};