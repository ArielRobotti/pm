import List "mo:base/List";
import Array "mo:base/Array";
import { now } "mo:base/Time";
import Principal "mo:base/Principal";
import Types "../../types";

module {

  public func delete(box: Types.CommentBox, path: [Int], caller: Principal): Types.DeleteResult {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    let result = deleteFrom(box.comments, path, caller);

    switch (result) {
      case (#Ok(comments)) {
        return #Ok({ box with comments;});
      };
      case (#Err(msg)) {
        return #Err(msg);
      };
    };
  };

  func deleteFrom(list: List.List<Types.Comment>, path: [Int], caller: Principal): { #Ok : List.List<Types.Comment>; #Err : Text } {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    var result = List.nil<Types.Comment>();
    var found = false;

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0] and not found) {
        found := true;
        if (path.size() == 1) {
          if (caller == comment.creator) {
            let anonymizedComment = {
              comment with
              msg = "";
              likes = [];
              dislikes = [];
              last_modification = ?now();
            };
            result := List.push<Types.Comment>(anonymizedComment, result);
          } else {
            return #Err("Access denied");
          };
        } else {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subResult = deleteFrom(comment.subComments, subPath, caller);
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