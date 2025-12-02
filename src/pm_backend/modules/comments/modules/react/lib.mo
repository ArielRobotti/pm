import List "mo:base/List";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Types "../../types";

module {

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


  func removeFromArray<T>(a: [T], e: T, equal: (T, T) -> Bool): [T] {
    Array.filter<T>(a, func u = not equal(u, e))
  };

  public func react(box: Types.CommentBox, path: [Int], reaction: ?Bool, caller: Principal): Types.ReactResult {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    let result = reactFrom(box.comments, path, reaction, caller);

    switch (result) {
      case (#Ok(comments)) {
        return #Ok({ box with comments; });
      };
      case (#Err(msg)) {
        return #Err(msg);
      };
    };
  };

  func reactFrom(list: List.List<Types.Comment>, path: [Int], reaction: ?Bool, caller: Principal): { #Ok : List.List<Types.Comment>; #Err : Text } {
    if (path.size() == 0) {
      return #Err("Invalid path");
    };

    var result = List.nil<Types.Comment>();
    var found = false;

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0] and not found) {
        found := true;
        if (path.size() == 1) {
          var likes = comment.likes;
          var dislikes = comment.dislikes;
          
          switch (reaction) {
            case (?true) { // Like
              likes := addIfNotInclude<Principal>(likes, caller, Principal.equal);
              dislikes := removeFromArray<Principal>(dislikes, caller, Principal.equal);
            };
            case (?false) { // Dislike
              dislikes := addIfNotInclude<Principal>(dislikes, caller, Principal.equal);
              likes := removeFromArray<Principal>(likes, caller, Principal.equal);
            };
            case (null) { // Clear
              likes := removeFromArray<Principal>(likes, caller, Principal.equal);
              dislikes := removeFromArray<Principal>(dislikes, caller, Principal.equal);
            };
          };

          let reactedComment = {
            comment with
            likes = likes;
            dislikes = dislikes;
          };
          result := List.push<Types.Comment>(reactedComment, result);
        } else {
          let subPath = Array.subArray<Int>(path, 1, path.size() - 1 : Nat);
          let subResult = reactFrom(comment.subComments, subPath, reaction, caller);
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