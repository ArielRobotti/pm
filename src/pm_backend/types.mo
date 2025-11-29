import Workspace "./modules/Workspace";
module {
  public type CommentArgs = {
    entity : Workspace.Entity;
    msg : Text;
    assetSize: ?Nat;
    path : [Int];
  };

};
