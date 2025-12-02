module {

  public type Metadata = [MetadataPart];

  public type MetadataPart = {
    key : Text;
    value : Value;
  };

  public type Value = {
    #Nat : Nat;
    #Int : Int;
    #Blob : Blob;
    #Text : Text;
    #Array : [Value];
    #Map : [(Text, Value)];
  };

};
