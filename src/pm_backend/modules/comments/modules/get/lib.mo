import List "mo:base/List";
import Array "mo:base/Array";
import Types "../../types";

module {
  
  public func getComment(list : List.List<Types.Comment>, path : [Int]) : ?Types.Comment {
    if (path.size() == 0) { return null };

    for (comment in List.toIter(List.reverse(list))) {
      if (comment.created_at == path[0]) {
        if (path.size() == 1) {
          return ?comment;
        } else {
          return getComment(comment.subComments, Array.subArray<Int>(path, 1, path.size() -1 : Nat));
        };
      };
    };
    return null;
  };
}