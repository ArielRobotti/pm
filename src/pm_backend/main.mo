
import Types "types";
import User "./modules/User";
import Workspace "./modules/Workspace";
import FileStorage "./modules/fileStorage";
import Principal "mo:base/Principal";
import Map "mo:map/Map";
import { ihash } "mo:map/Map";
import Set "mo:map/Set";
import List "mo:base/List";
import { now } "mo:base/Time";
import { print } "mo:base/Debug";
import Int "mo:base/Int";
import Notifications "./modules/notifications";

shared ({caller = SUPER_ADMIN}) persistent actor class() = this {

  type UID = Workspace.UID;

  let users = User.init(SUPER_ADMIN);

  let tempComments = Map.new<Int, Types.CommentArgs and {user: Principal}>();

  let workspaces = Workspace.init({bucketAdmins = [SUPER_ADMIN, Principal.fromActor(this)]; pm = Principal.fromActor(this) });

  //// Admin functions test ///

  public shared ({ caller }) func testUploadFileRequest(size: Nat): async FileStorage.GetStorageResponse {
    assert(User.isUser(users, caller));
    await FileStorage.getStorageFor(workspaces.fileStorage, size, caller, [], null)
  };

  public shared ({ caller }) func getFilestorageInfo(): async [(Int, FileStorage.StorageLocation)] {
    // assert (User.isAdmin(users, caller));
    Map.toArray<Int, FileStorage.StorageLocation>(workspaces.fileStorage.index)
  };

  public shared ({ caller }) func getBucketsMetadata(): async [(Principal, FileStorage.BucketMetadata)]{
    Map.toArray<Principal, FileStorage.BucketMetadata>(workspaces.fileStorage.buckets)
  };

  public shared ({ caller }) func backet_canister_status(canisterId: Principal): async FileStorage.CanisterStatusResult {

    await FileStorage.canisterStatus(canisterId)
  };

  public shared ({caller})func onFileLoaded({internalId: Int; tempIdSource: ?Int}): async Int {
    print("Recibiendo notificacion de canister Bucket " # debug_show(caller));
    assert(FileStorage.isBucketCanister(workspaces.fileStorage, caller));
    let id = now();
    FileStorage.indexFile(workspaces.fileStorage, id, {canisterId = caller; internalId});
    /// Si la fuente del file es un comentario ///
    switch tempIdSource{
      case null { };
      case( ?(id) ) {
        print("El archivo fue cargado desde un comentario");
        // posiblemente se requiera  generalizar CommentArgs para incluir la carga de multimedia en un contexto de mensaje interno
        switch (Map.get<Int, Types.CommentArgs and {user: Principal}>(tempComments, ihash, id)) {
          case null { };
          case ( ?data ){
            print("Comentario temporal encontrado");
            // se incrusta el datastorage del archivo en el cuerpo del mensaje antes de incluirlo en el BoxComment
            let msgWithIncrustedDataStorage 
              = Principal.toText(caller) // Este es el Bucket
              # "/"
              # Int.toText(internalId)
              # "<<END-DATA-STORAGE>>"
              # data.msg
            ;
            ignore Workspace.pushComment(workspaces, {data with msg = msgWithIncrustedDataStorage}, data.user)
          }
        }
      }
    };
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

  public shared query ({ caller }) func getMyNotifications(): async [Notifications.Notification]{
    List.toArray<Notifications.Notification>(
      Notifications.getNotificationsFor(
        workspaces.userNotifications, caller
      )
    )
  };

  public shared ({ caller }) func readNotification(id: Int): async {#Err : Text; #Ok}{
    Notifications.markAsRead(workspaces.userNotifications, caller ,id)
  };

  public shared ({ caller }) func deleteNotification(id: Int): async {#Err : Text; #Ok}{
    Notifications.deleteNotification(workspaces.userNotifications, caller ,id)
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

  public shared query ({ caller }) func getMyWorkspaces(): async [Types.EntityCard]{
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

  public shared ({ caller }) func getProjectCardsFrom(wsid: UID): async [Types.EntityCard]{
    Workspace.getProjectsCardFrom(workspaces, caller, wsid)
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

  public shared ({ caller }) func comment(args: Types.CommentArgs): async Workspace.PushCommentResult{
    switch (args.assetSize) {
      case null { };
      case ( ?assetSize ) {
        // Si el comentario incluye multimedia,
        // 1. Se genera un id temporal bajo el que guarda en un mapa, el comentario a la espera de la carga del archivo multimedia
        let tempIdSource = now();
        ignore Map.put<Int, Types.CommentArgs and {user: Principal}>(tempComments, ihash, tempIdSource, {args with user = caller});
        // 2. Se pide almacenamiento en el Bucket Manager indicandole ademas el id temporal
        let members = Workspace.getMembersFrom(workspaces, args.entity);
        let dataForStorage = await FileStorage.getStorageFor(workspaces.fileStorage, assetSize, caller, members, ?tempIdSource);
        // 3. Se retorna al front la informacion para subir los chunks
        return #RequireFileUpload(dataForStorage)
        // Lo que pasa despues:
        // 1. El front envia los chunks al Bucket y cuando este recibe el ultimo llama a la funcion callback de PM
        // 2. El Bucket envia mediante esa funcion, el id interno asignado al nuevo archivo y el id temporal asociado al comentario
        // 3. El canister PM tomara ese comentario, incrustara la datastorage en el cuerpo del mensaje y completará pushComment
        // Todo esta logica se implementa dentro de la funcion onFileLoaded
      }
    };
    ////
    Workspace.pushComment(workspaces, args, caller)
  };

  public shared ({ caller }) func deleteComment({entity: Workspace.Entity; path: [Int]}): async Workspace.DeleteResult {
    // TODO Borrar archivo multimedia si se incluye
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
