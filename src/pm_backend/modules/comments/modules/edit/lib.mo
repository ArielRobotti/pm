import List "mo:base/List";
import Array "mo:base/Array";
import { now } "mo:base/Time";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Types "../../types";

module {

  public func edit(box: Types.CommentBox, path: [Int], newMsg: Text, caller: Principal): Types.EditResult {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    let result = editFrom(box.comments, path, newMsg, caller);

    switch (result) {
      case (#Ok(comments)) {
        return #Ok({ box with comments; });
      };
      case (#Err(msg)) {
        return #Err(msg);
      };
    };
  };

  func editFrom(list: List.List<Types.Comment>, path: [Int], _newMsg: Text, caller: Principal): { #Ok : List.List<Types.Comment>; #Err : Text } {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    var result = List.nil<Types.Comment>();
    var found = false;

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0] and not found) {
        found := true;
            let separator = "<<END-DATA-STORAGE>>";
            let newMsg = if(Text.contains(comment.msg , #text(separator))) {
              Iter.toArray(Text.split(comment.msg, #text(separator)))[0]
              # separator
              # _newMsg
            } else {
              _newMsg
            };
        if (path.size() == 1) {
          if (caller == comment.creator) {
            let editedComment = {
              comment with
              msg = newMsg;
              last_modification = ?now();
            };
            result := List.push<Types.Comment>(editedComment, result);
          } else {
            return #Err("Access denied");
          };
        } else {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subResult = editFrom(comment.subComments, subPath, newMsg, caller);
          switch (subResult) {
            case (#Ok(subComments)) {
              result := List.push<Types.Comment>({ comment with subComments }, result);
            };
            case (#Err(msg)) {
              return #Err(msg);
            };
          };
        };
      } else {
        result := List.push<Types.Comment>(comment, result);
      };
    };

    if (not found) {
      return #Err("Comment not found");
    };

    return #Ok(result);
  };
}