import List "mo:base/List";
import { now } "mo:base/Time";
import Principal "mo:base/Principal";
import Types "../../types";

module {

  public func newComment(msg : Text, caller : Principal) : Types.Comment {
    {
      created_at : Int = now();
      creator : Principal = caller;
      dislikes : [Principal] = [];
      last_modification : ?Int = null;
      likes : [Principal] = [];
      msg;
      subComments = List.nil<Types.Comment>();
    };
  };

  public func newBox({ depthLimit : Nat }) : Types.CommentBox {
    { depthLimit; comments = List.nil<Types.Comment>(); size = 0; };
  };

}