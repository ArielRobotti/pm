import List "mo:base/List";
import Principal "mo:base/Principal";
import FileStorage "../fileStorage";

module {

  // ======== Types ========= //

  public type CommentBox = {
    depthLimit : Nat;
    comments : List.List<Comment>;
    size: Nat
  };

  public type PushResult = { 
    #Ok : CommentBox; 
    #RequireFileUpload: FileStorage.GetStorageResponse; 
    #Err : Text 
  };

  public type DeleteResult = { #Ok : CommentBox; #Err : Text };
  public type EditResult = { #Ok : CommentBox; #Err : Text };
  public type ReactResult = { #Ok : CommentBox; #Err : Text };

  public type Comment = {
    created_at : Int;
    last_modification : ?Int;
    creator : Principal;
    msg : Text; // incluye referencias a archivos multimedia
    likes : [Principal];
    dislikes : [Principal];
    subComments : List.List<Comment>;
  };

  public type Like = {
    #Like;
    #Dislike;
    #Clear;
  };
}