import Map "mo:map/Map";
import Principal "mo:base/Principal";
import FileStorage "./modules/fileStorage";
import CommentsTypes "./modules/comments/types";
import Notification "./modules/notifications/types";

module {

  public type UID = Int; //Date of creation

  public type UserResources = {
    workspaces : [UID];
    projects : [UID];
  };

  public type State = {
    userResources : Map.Map<Principal, UserResources>;
    userNotifications: Notification.NotificationStore;
    workspaces : Map.Map<Int, Workspace>;
    projects : Map.Map<Int, Project>;
    fileStorage: FileStorage.FileStorage;
  };

  public type Entity = {
    #Workspace : UID;
    #Project : UID;
    #Area : [UID];
  };
  public type EntityEditableData = {
    name : Text;
    description : Text;
    details : Text;
    coverImage : ?Blob;
    logo : ?Blob;
  };

  public type OptEntityEditableData = {
    name : ?Text;
    description : ?Text;
    details : ?Text;
    coverImage : ?Blob;
    logo : ?Blob;
  };

  public type EntityMetadata = EntityEditableData and {
    id : UID;
  };

  public type Workspace = EntityMetadata and {
    owner : Principal;
    admins : [Principal];
    members : [Principal];
    projectIds : [UID];
  };

  public type Project = EntityMetadata and {
    id : UID;
    client : ?UID;
    projectOwner : Principal;
    members : [Principal];
    workspace : UID; // vinculo bidireccional necesario?
    areas : [Area];
    commentBox: CommentsTypes.CommentBox;
  };

  public type Comment = CommentsTypes.Comment;

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
    #Review : ChangeRecord;
    #Done : ChangeRecord;
    #Custom : { customStatus : Text; change : ChangeRecord };
  };

  public type Task = EntityMetadata and {
    tags : [Text];
    status : TastStatus;
    deadline : Int;
    assignedUsers : [Principal];
  };

  public type CommentArgs = {
    entity : Entity;
    msg : Text;
    assetSize: ?Nat;
    path : [Int];
  };
}