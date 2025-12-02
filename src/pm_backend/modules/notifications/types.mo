import SharedTypes "../shared_types";
import List "mo:base/List";
import Map "mo:map/Map";

module {

  public type NotificationStore = {
    notifications : Map.Map<Principal, List.List<Notification>>;
    limitPerUser: Nat; // Cantidad limite de notificaciones por usuario
    storageTimeLimit: Int;  // Tiempo limite de guardado de notificaciones:
  };

  public type NID = Int;

  public type KeyValue = SharedTypes.MetadataPart;

  public type NotificationContext = {
    root : Int; // ID del elemento principal (Ej: Proposal Id, Post Id, etc.)
    path : [Int]; // Ruta jerárquica hasta el subelemento específico (Ej: comentario, subcomentario ID)
    senderName : Text;
    sender : Principal;
  };

  public type NotificationKind = {
    #IntegratedAsMember : {
      autor: Principal;
      path: [Int] //[Workspace, Project, area, subarea... etc]
    };
    #NewComment: { 
      autor: Principal; 
      msg: Text 
    };
    #ReactComment : NotificationContext and {
      reaction : Nat8; // La reaccion se especifica con el indice del array reactions
    };
    #CommentReply : NotificationContext and {
      msg : Text;
    };
    #NewMention : NotificationContext and {
      msg : Text;
    };
    #System: KeyValue;
    #GenericNotification : KeyValue;
  };

  public type Notification = {
    date : NID; // Notification Id is the timestamp
    kind : NotificationKind;
    resume : Text;
    read : Bool;
  };

  
};
