module LUA-SYNTAX
  syntax Id ::= r"(?<![A-Za-z0-9\\_])[A-Za-z\\_][A-Za-z0-9\\_]*" [token, autoReject, avoid]

  syntax Nil ::= "nil"
  syntax Varargs ::= "..."

  syntax Value ::= Nil | Bool | Float | String

  syntax Block ::= Statements ReturnStatement
                 | Statements

  syntax Statement ::= ";" [klabel(SemicolonStmt)]
                     | VarList "=" ExpressionList [strict(2)]
                     | FunctionCall
                     | "break"
                     | "if" Expression "then" Block EndIf
                     | "do" Block "end"
                     | "while" Expression "do" Block "end"
                     | "repeat" Block "until" Expression
                     | "for" Id "=" Expression "," Expression "do" Block "end"
                     | "for" Id "=" Expression "," Expression "," Expression "do" Block "end"
                     | "for" IdList "in" ExpressionList "do" Block "end" [strict(2)]
                     | "function" FuncName FuncBody
                     | "local" "function" Id FuncBody
                     | "local" IdList
                     | "local" IdList "=" ExpressionList [strict(2)]
  syntax Statements ::= List{Statement, " "} [klabel(Statements)]

  syntax EndIf ::= "end"
                 | "else" Block "end"
                 > "elseif" Expression "then" Block EndIf

  syntax FuncName ::= IdDotList
                    | IdDotList ":" Id

  syntax IdList ::= NeList{Id, ","}
  syntax IdDotList ::= NeList{Id, "."}

  syntax ReturnStatement ::= "return" ExpressionList
                           | "return"
                           > ReturnStatement ";"

  syntax Expression ::= Value
                      | PrefixExpression
                      | TableConstructor
                      | "function" FuncBody
                      | Varargs
                      > Expression "^" Expression
                      > "not" Expression [left]
                      | "#" Expression [left]
                      | "-" Expression [left]
                      | "~" Expression [left]
                      > Expression "*" Expression [left]
                      | Expression "/" Expression [left]
                      | Expression "/ /" Expression [left] // luakast turns '//' into '/ /'
                      | Expression "i/ /" Expression [left] // luakast turns '[Int] //' into 'i/ /'
                      | Expression "%" Expression [left]
                      > Expression "+" Expression [left]
                      | Expression "-" Expression [left]
                      > Expression ".." Expression [left]
                      > Expression "<<" Expression [left]
                      | Expression ">>" Expression [left]
                      > Expression "&" Expression [left]
                      > Expression "~" Expression [left]
                      > Expression "|" Expression [left]
                      > Expression "<" Expression [left]
                      | Expression ">" Expression [left]
                      | Expression "<=" Expression [left]
                      | Expression ">=" Expression [left]
                      | Expression "~=" Expression [left]
                      | Expression "==" Expression [left]
                      > Expression "and" Expression [left]
                      > Expression "or" Expression [left]
  syntax ExpressionList ::= NeList{Expression, ","}

  syntax PrefixExpression ::= Var
                            | FunctionCall
                            | "(" Expression ")" [bracket]

  syntax FunctionCall ::= FunctionRef "(" ExpressionList ")" [strict(2)]
                        | FunctionRef "(" ")"
                        | FunctionRef String
  syntax FunctionRef ::= PrefixExpression
                       | PrefixExpression ":" Id

  syntax FuncBody ::= "(" ParamList ")" Block "end"
                    | "(" ")" Block "end"
  syntax ParamList ::= Varargs
                     | Id
                     > Id "," ParamList

  syntax Var ::= Id
               | PrefixExpression "[" Expression "]"
               | PrefixExpression "." Id
  syntax VarList ::= NeList{Var, ","}

  syntax TableConstructor ::= "{" FieldList "}"
                            | "{" FieldList FieldSep "}"
                            | "{" FieldSep "}"
                            | "{" "}"
  syntax FieldList ::= Field
                     | Field FieldSep FieldList
  syntax FieldSep ::= "," | ";"
  syntax Field ::= "[" Expression "]" "=" Expression
                 | Id "=" Expression
                 | Expression
endmodule

module LUA
  imports LUA-SYNTAX
  imports FLOAT

  configuration <T>
                  <k>
                    local _ENV = { string = {} } ~> (_G = _ENV):Statement

                    // builtin functions
                    ~> (print = function(...) #print(...) .Statements end):Statement
                    ~> (next = function(t, i) .Statements return #next(t, i) end):Statement
                    ~> (type = function(o) .Statements return #typeFunc(o) end):Statement
                    ~> (error = function(m) .Statements return #error(m) end):Statement
                    ~> (pcall = function(f, ...) .Statements return #pcall(f, ...) end):Statement

                    ~> $PGM:Statements
                  </k>
                  <env> .Map </env>
                  <store> .Map </store>
                  <heap> .Map </heap>
                  <fstack> .List </fstack>
                  <out stream="stdout"> .List </out>
                  <freshint> 0 </freshint>
                  <error> . </error>
                </T>

  syntax Value ::= TablePtr | FuncPtr
  syntax ValueList ::= List{Value, ","}
  syntax ExpressionList ::= ValueList
  syntax KResult ::= Value | ValueList | Int


  syntax Float ::= IntToFloat(Int) [function]
  rule IntToFloat(N:Int) => Int2Float(N, 53, 11)

  syntax K ::= "#freshint" "(" ")"
  rule <k> #freshint() => V ...</k>
       <freshint> V => V +Int 1 </freshint>


  // statements
  rule S:Statement Ss:Statements => S ~> Ss
  rule .Statements => .
  rule S:Statements R:ReturnStatement => S ~> R
  rule E:ExpressionList ~> S:Statements => S // throw away unused results
  rule (;):Statement => .

  // tables
  syntax TablePtr ::= "Table" "<" Int ">"
  syntax FunctionCall ::= #newTable(K) [strict]

  rule {} => #newTable(#freshint())
  rule <k> #newTable(L:Int) => Table<L:Int> ...</k>
       <heap> M:Map => M[L:Int <- .Map] </heap>

  syntax K ::= #buildTable(Expression, Expression, FieldList) [strict(1, 2)]
  rule {... S:FieldSep => . }
  rule { L:FieldList } => #buildTable({}, 1.0, L)
  rule #buildTable(T:TablePtr, Pos:Float, V:Expression _:FieldSep Ls:FieldList) =>
    #set(T, Pos, V) ~> #buildTable(T, Pos +Float 1, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, V:Expression) => #set(T, Pos, V) ~> T
  rule #buildTable(T:TablePtr, Pos:Float, K:Id = V:Expression _:FieldSep Ls:FieldList) =>
    #set(T, Id2String(K), V) ~> #buildTable(T, Pos, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, K:Id = V:Expression) => #set(T, Id2String(K), V) ~> T

  // functions
  syntax FuncPtr ::= "Func" "<" Int ">"
  syntax FuncDef ::= "FuncDef" "<" ParamList "," Block "," Map ">"
                   | "FuncDef" "<" Block "," Map ">"

  syntax FunctionCall ::= #newFunc(FuncBody, K) [strict(2)]
  rule function(Args:ParamList) Block:Block end => #newFunc((Args:ParamList) Block:Block end, #freshint())
  rule function() Block:Block end => #newFunc(() Block:Block end, #freshint())
  rule <k> #newFunc((Args:ParamList) Block:Block end, L:Int) => Func<L> ...</k>
       <env> Env </env>
       <heap> M:Map => M[L <- FuncDef<Args, Block, Env>] </heap>
  rule <k> #newFunc(() Block:Block end, L:Int) => Func<L> ...</k>
       <env> Env </env>
       <heap> M:Map => M[L <- FuncDef<Block, Env>] </heap>

  rule function N:IdDotList B:FuncBody => #assign(#idDotListToVar(N:IdDotList), function B)
  rule local function Name:Id Body:FuncBody => local Name = function Body

  syntax Var ::= #idDotListToVar(IdDotList) [function]
               | #idDotListToVarImpl(IdDotList, Var) [function]
  rule #idDotListToVar(N:Id . Ns:IdDotList) => #idDotListToVarImpl(Ns, N)
  rule #idDotListToVarImpl((N:Id . Ns:IdDotList), V:Var) => #idDotListToVarImpl(Ns, (V . N))
  rule #idDotListToVarImpl(.IdDotList, V:Var) => V

  // value list utils
  syntax ValueList ::= #reverseList(ValueList) [function]
                     | #reverseListImpl(ValueList, ValueList) [function]
  rule #reverseList(I) => #reverseListImpl(I, .ValueList)
  rule #reverseListImpl((I:Value, Is:ValueList), J) => #reverseListImpl(Is, (I:Value, J:ValueList))
  rule #reverseListImpl(.ValueList, J) => J

  syntax ValueList ::= #concatList(ValueList, ValueList) [function]
                     | #concatListImpl(ValueList, ValueList) [function]
  rule #concatList(A:ValueList, B:ValueList) => #concatListImpl(#reverseList(A), B)
  rule #concatListImpl((A:Value, As:ValueList), B:ValueList) => #concatListImpl(As, (A:Value, B:ValueList))
  rule #concatListImpl(.ValueList, B:ValueList) => B

  // set utils
  syntax List ::= #setToList(Set) [function]
                | #setToListImpl(Set, List) [function]
  rule #setToList(S:Set) => #setToListImpl(S, .List)
  rule #setToListImpl(SetItem(X) S:Set, L:List) => #setToListImpl(S, L ListItem(X))
  rule #setToListImpl(.Set, L:List) => L

  // evaluation
  syntax FunctionCall ::= #eval(ExpressionList) [function]
                        | #eval1(ExpressionList) [strict]
  rule #eval1(E:Value, Es:ValueList) => E:Value
  rule #eval1(.ValueList) => nil

  syntax FunctionCall ::= #evalImpl(ExpressionList, K, ValueList) [strict(2)]
  rule #eval(E:Expression, Es:ExpressionList) => #evalImpl(Es:ExpressionList, E:Expression, .ValueList)
  rule #evalImpl((E:Expression, Es:ExpressionList), R:Value, Out:ValueList) =>
    #evalImpl(Es:ExpressionList, E:Expression, (R:Value, Out:ValueList))
  rule #evalImpl((E:Expression, Es:ExpressionList), (R:Value, Rs:ValueList), Out:ValueList) =>
    #evalImpl(Es:ExpressionList, E:Expression, (R:Value, Out:ValueList))
  rule #evalImpl(.ExpressionList, R:Value, Out:ValueList) =>
    #evalImpl(.ExpressionList, (R:Value, .ValueList), Out:ValueList)
  rule #evalImpl(.ExpressionList, R:ValueList, Out:ValueList) => #concatListImpl(Out, R:ValueList)

  rule E:ExpressionList => #eval(E) when notBool isValueList(E)

  // function call
  syntax FunctionCall ::= #call(FunctionRef, ExpressionList) [strict(2)]
                        | #callEntry(Expression, ExpressionList) [strict]
                        | #callEntry(FuncDef, ValueList)
                        | #callImpl(FuncDef, ValueList)

  rule F:FunctionRef(Args:ValueList) => #call(F, Args)
  rule F:FunctionRef() => #call(F, .ExpressionList)
  rule F:FunctionRef S:String => #call(F, (S, .ValueList))

  rule #call(E:PrefixExpression : Es:Id, Args:ValueList) => #call((E . Es), #eval(#eval1(E), Args))
  rule #call(E:PrefixExpression, Args:ValueList) => #callEntry(E, Args)

  rule <k> #callEntry(Func<L:Int>, Args:ValueList) =>
              #enter(CallFrame, #callEntry(M:FuncDef, Args) ~> return) ...</k>
       <heap>... L |-> M:FuncDef ...</heap>
  rule #callEntry(FuncDef<P:ParamList, B:Block, Env:Map>, Args:ValueList) =>
    #setEnv(Env) ~> #declareLocal("...") ~> #callImpl(FuncDef<P, B, Env>, Args)
  rule #callEntry(FuncDef<B:Block, Env:Map>, Args:ValueList) =>
    #setEnv(Env) ~> #declareLocal("...") ~> #callImpl(FuncDef<B, Env>, Args)

  rule #callImpl(FuncDef<(N:Id, Ns:ParamList), B:Block, Env:Map>, (Arg:Value, Args:ValueList)) =>
    local N = Arg ~> #callImpl(FuncDef<Ns, B, Env>, Args)
  rule #callImpl(FuncDef<N:Id, B:Block, Env:Map>, (Arg:Value, Args:ValueList)) =>
    local N = Arg ~> #callImpl(FuncDef<B, Env>, Args)
  rule #callImpl(FuncDef<N:ParamList, B:Block, Env:Map>, .ValueList) =>
    #callImpl(FuncDef<B, Env>, .ValueList)
  rule <k> #callImpl(FuncDef<(...):Varargs, B:Block, Env:Map>, Args:ValueList) =>
             #callImpl(FuncDef<B, Env>, .ValueList) ...</k>
       <env>... "..." |-> L:Int ...</env>
       <store>... L |-> (_ => Args) ...</store>
  rule #callImpl(FuncDef<B:Block, Env:Map>, Args:ValueList) => B

  syntax K ::= #setEnv(Map)
  rule <k> #setEnv(M:Map) => . ...</k>
       <env> _ => M:Map </env>

  syntax StackFrame ::= "StackFrame" "<" FrameType "," Map "," K ">"
  syntax FrameType ::= "CallFrame" | "LoopFrame" | "ScopeFrame" | "CatchFrame"
  syntax K ::= #enter(FrameType, K)
  rule <k> #enter(T:FrameType, B) ~> Rest => B </k>
       <env> M </env>
       <fstack> .List => ListItem(StackFrame<T, M, Rest>) ...</fstack>

  syntax FunctionCall ::= #return(FrameType, ExpressionList) [strict(2)]
                        | #return(FrameType) [klabel(#return_nil)]
                        | #returnImpl(FrameType, K)
  rule <k> #return(T:FrameType, E:ValueList) ~> Rest:K => #returnImpl(T, (E:ValueList):K) </k>
  rule <k> #return(T:FrameType, E:ValueList) => #returnImpl(T, E:ValueList) </k>
  rule <k> #return(T:FrameType) ~> Rest:K => #returnImpl(T, .) </k>
  rule <k> #return(T:FrameType) => #returnImpl(T, .) </k>

  rule <k> #returnImpl(T:FrameType, E:K) => E ~> Rest </k>
       <env> _ => M </env>
       <fstack> ListItem(StackFrame<T, M, Rest>) => .List ...</fstack>
  rule <k> #returnImpl(T:FrameType, E:K) => #checkValidReturn(T, Type) ~> #returnImpl(T, E) </k>
       <fstack> ListItem(StackFrame<Type:FrameType, M, Rest>) ...</fstack> when T =/=K Type
  rule <k> true ~> #returnImpl(T:FrameType, E:K) => #returnImpl(T, E) </k>
       <fstack> ListItem(StackFrame<Type, M, Rest>) => .List ...</fstack>

  rule <k> . => Rest </k>
       <env> _ => M </env>
       <fstack> ListItem(StackFrame<T, M, Rest>) => .List ...</fstack>

  syntax Bool ::= #checkValidReturn(FrameType, FrameType)
  rule #checkValidReturn(CallFrame, LoopFrame) => true
  rule #checkValidReturn(CallFrame, ScopeFrame) => true
  rule #checkValidReturn(LoopFrame, ScopeFrame) => true
  rule #checkValidReturn(CatchFrame, _) => true

  rule R:ReturnStatement ; => R
  rule return E:ExpressionList => #return(CallFrame, E:ExpressionList)
  rule return => #return(CallFrame, .ExpressionList)

  // variable declaration
  rule local N:IdList = V:ValueList => local N ~> N = V:ValueList
  rule local N:Id, Ns:IdList => #declareLocal(Id2String(N)) ~> local Ns
  rule local .IdList => .

  syntax K ::= #declareLocal(String) [function]
             | #declareLocalImpl(String, K) [strict]
  rule #declareLocal(N:String) => #declareLocalImpl(N:String, #freshint())
  rule <k> #declareLocalImpl(N:String, L:Int) => . ...</k>
       <env> M => M[N <- L] </env>
       <store> R => R[L <- nil] </store>

  // variable assignment
  syntax K ::= #assignList(VarList, ExpressionList) [strict(2), function]
  rule V:VarList = E:ValueList => #assignList(V:VarList, E:ValueList)
  rule #assignList((V:Var, Vs:VarList), (E:Value, Es:ValueList)) =>
    #assign(V:Var, E:Value) ~> #assignList(Vs:VarList, Es:ValueList)
  rule #assignList(.VarList, _) => .

  syntax K ::= #assign(Var, Expression) [strict(2)]
  rule <k> #assign(N:Id, V:Value) => . ...</k>
       <env>... Id2String(N) |-> L:Int ...</env>
       <store>... L |-> (_ => V) ...</store>
  rule <k> #assign(N:Id, V:Value) => #set(_ENV, Id2String(N), V) ...</k>
       <env> M </env> when notBool(Id2String(N) in keys(M))
  rule #assign(N:PrefixExpression [ K:Expression ], V:Value) => #set(N, K, V)
  rule #assign((N:PrefixExpression . K:Id):Var, V:Value) => #set(N, Id2String(K), V)

  // variable lookup
  rule <k> Name:Id => V ...</k>
       <env>... Id2String(Name) |-> L:Int ...</env>
       <store>... L |-> V ...</store>
  rule <k> Name:Id => #get(_ENV, Id2String(Name)) ...</k>
       <env> M </env> when notBool(Id2String(Name) in keys(M))
  rule <k> (...):Varargs => V ...</k>
       <env>... "..." |-> L:Int ...</env>
       <store>... L |-> V ...</store>

  // table set
  syntax FunctionCall ::= #set(Expression, Expression, Expression) [strict]
  rule #set(T:Value, K:Value, V:Value) => #rawset(T, K, V)

  syntax FunctionCall ::= #rawset(Expression, Expression, Expression) [strict]
  rule <k> #rawset(Table<T:Int>, N:Value, V:Value) => . ...</k>
       <heap>... T |-> (M:Map => M[N <- V]) ...</heap>
  rule #rawset(T:Value, N:Value, V:Value) => #error("attempt to index") when notBool isTablePtr(T)

  // table get
  syntax FunctionCall ::= #get(Expression, Expression) [strict]
  rule #get(T:Value, K:Value) => #rawget(T, K)

  syntax FunctionCall ::= #rawget(Expression, Expression) [strict]
  rule <k> #rawget(Table<T:Int>, N:Value) => M:Map[N] ...</k>
       <heap>... T |-> M:Map ...</heap> when N in keys(M)
  rule <k> #rawget(Table<T:Int>, N:Value) => nil ...</k>
       <heap>... T |-> M:Map ...</heap> when notBool(N in keys(M))
  rule #rawget(T:Value, N:Value) => #error("attempt to index") when notBool isTablePtr(T)

  rule E:PrefixExpression [ K:Expression ] => #get(E, K)
  rule (E:PrefixExpression . K:Id):Var => #get(E, Id2String(K))

  // if
  syntax K ::= #if(Expression, Block, EndIf) [strict(1)]
  rule #if(true, B:Block, E:EndIf) => #enter(ScopeFrame, B)
  rule #if(false, B:Block, E:EndIf) => E

  rule if E:Expression then B:Block F:EndIf => #if(#toboolean(E), B, F)
  rule elseif E:Expression then B:Block F:EndIf => if E then B F
  rule else B:Block end => #enter(ScopeFrame, B)
  rule end => .

  // do
  rule do B:Block end => #enter(ScopeFrame, B)

  // while
  syntax K ::= #while(Expression, Block)
  rule #while(E:Expression, B:Block) => #toboolean(E) ~> #while(E, B)
  rule true ~> #while(E:Expression, B:Block) => #enter(ScopeFrame, B) ~> #while(E, B)
  rule false ~> #while(E:Expression, B:Block) => .

  rule while E:Expression do B:Block end => #enter(LoopFrame, #while(E, B))
  rule break => #return(LoopFrame)

  // repeat
  rule repeat B:Block until E:Expression => #enter(LoopFrame, B ~> #while(not E, B))

  // numeric for
  syntax K ::= #nfor(Id, Expression, Expression, Expression, Block) [strict(2, 3, 4)]
  rule #nfor(N:Id, Var:Value, Limit:Value, 0.0, B:Block) => .
  rule #nfor(N:Id, Var:Value, Limit:Value, Step:Value, B:Block) =>
    (Step >= 0.0 and Var > Limit) or (Step < 0.0 and Var < Limit) ~>
    #nfor(N, Var, Limit, Step, B) when Step:Value =/=K (0.0):Float
  rule true ~> #nfor(N:Id, Var:Expression, Limit:Value, Step:Value, B:Block) => break
  rule false ~> #nfor(N:Id, Var:Expression, Limit:Value, Step:Value, B:Block) =>
    local N = Var ~> B ~> #nfor(N, Var + Step, Limit, Step, B)

  rule for N:Id = X:Expression, Y:Expression do B:Block end => for N = X, Y, 1 do B end
  rule for N:Id = X:Expression, Y:Expression, Z:Expression do B:Block end =>
    #enter(LoopFrame, #nfor(N, #eval1(X), #eval1(Y), #eval1(Z), B))

  // iterator for
  syntax K ::= #ifor(IdList, Expression, Expression, Expression, Block) [strict(2, 3, 4)]
             | #iforStep(IdList, Expression, Expression, ExpressionList, Block) [strict(2, 3, 4)]
  rule #ifor(N:IdList, F:Value, S:Value, Var:Value, B:Block) =>
    #iforStep(N, F, S, #callEntry(F:Value, (S, Var, .ValueList)), B)
  rule #iforStep(N:IdList, F:Value, S:Value, (Var:Value, Vars:ValueList), B:Block) =>
    local N ~> #assignList(N, (Var:Value, Vars:ValueList)) ~> Var == nil ~>
    #ifor(N:IdList, F:Value, S:Value, Var:Value, B:Block)
  rule #iforStep(N:IdList, F:Value, S:Value, .ValueList, B:Block) => break
  rule true ~> #ifor(N:IdList, F:Value, S:Value, Var:Value, B:Block) => break
  rule false ~> #ifor(N:IdList, F:Value, S:Value, Var:Value, B:Block) => B ~> #ifor(N, F, S, Var, B)

  rule for N:IdList in (F:Value, (S:Value, (Var:Value, Rest:ValueList))) do B:Block end =>
    #enter(LoopFrame, #ifor(N, F, S, Var, B))

  // builtin print
  syntax FunctionCall ::= #print(ExpressionList) [strict]
  rule <k> #print(V:Value, Vs:ValueList) => #print(Vs) ...</k>
       <out>... .List => ListItem(#tostring(V) +String " ") </out> when Vs =/=K .ValueList
  rule <k> #print(V:Value, .ValueList) => #print(.ValueList) ...</k>
       <out>... .List => ListItem(#tostring(V) +String "\n") </out>
  rule #print(.ValueList) => .

  // builtin tostring
  syntax String ::= #tostring(Expression) [strict, function]
  rule #tostring(S:String) => S
  rule #tostring(N:Float) => Int2String(Float2Int(N)) when N %Float 1.0 ==Float 0.0
  rule #tostring(N:Float) => Float2String(N) when N %Float 1.0 =/=Float 0.0
  rule #tostring(true) => "true"
  rule #tostring(false) => "false"
  rule #tostring(nil) => "nil"

  // builtin next
  syntax FunctionCall ::= #next(Expression, Expression) [strict]
                        | #nextImpl(TablePtr, List, Value)
  rule <k> #next(Table<L:Int>, I:Value) =>
             #nextImpl(Table<L>, #setToList(keys(M:Map)), I:Value) ...</k>
       <heap>... L |-> M:Map ...</heap>
  rule #nextImpl(T:TablePtr, ListItem(I:Value) Rest:List, nil) => #eval(I, #rawget(T, I))
  rule #nextImpl(T:TablePtr, ListItem(I:Value) Rest:List, J:Value) =>
    #nextImpl(T, Rest:List, J) when I =/=K J andBool J =/=K nil
  rule #nextImpl(T:TablePtr, ListItem(I:Value) Rest:List, I:Value) => #nextImpl(T, Rest, nil)
  rule #nextImpl(T:TablePtr, .List, I:Value) => nil

  // builtin type
  syntax FunctionCall ::= #type(Expression) [strict, function]
                        | #typeFunc(Expression) [strict]
  rule #typeFunc(V:Value) => #type(V)
  rule #type(nil) => "nil"
  rule #type(B:Bool) => "boolean"
  rule #type(N:Float) => "number"
  rule #type(S:String) => "string"
  rule #type(F:FuncPtr) => "function"
  rule #type(T:TablePtr) => "table"

  // builtin error
  syntax FunctionCall ::= #error(Expression) [strict]
  rule <k> #error(V:Value) => #return(CatchFrame) ...</k>
       <error> . => "[script]:1: " +String #tostring(V) </error>

  // builtin pcall
  syntax FunctionCall ::= #pcall(Expression, ExpressionList) [strict]
  syntax K ::= "#pcallRet" "(" ")"
  rule #pcall(F:Value, V:ValueList) =>
    #enter(CatchFrame, #return(CatchFrame, #callEntry(F, V))) ~> #pcallRet()
  rule <k> #pcallRet() => (false, Err:Value, .ValueList) ...</k>
       <error> Err:Value => . </error>
  rule <k> V:ValueList ~> #pcallRet() => (true, V:ValueList) ...</k>
       <error> . </error>



  // predefined error types
  syntax K ::= #arithmeticError(Value) [function]
  rule #arithmeticError(V:Value) => #error("attempt to perform arithmetic on a " .. #type(V) .. " value")

  syntax K ::= #lengthError(Value) [function]
  rule #lengthError(V:Value) => #error("attempt to get length of a " .. #type(V) .. " value")

  syntax K ::= #bitwiseOpError(Value) [function]
  rule #bitwiseOpError(V:Value) => #error("attempt to perform bitwise operation on a " .. #type(V) .. " value")

  syntax K ::= #concatError(Value) [function]
  rule #concatError(V:Value) => #error("attempt to concatenate a " .. #type(V) .. " value")

  syntax K ::= #compareError(Value, Value) [function]
  rule #compareError(A:Value, B:Value) => #error("attempt to compare two " .. #type(A) .. " values")
    when #type(A) ==K #type(B)
  rule #compareError(A:Value, B:Value) => #error("attempt to compare " .. #type(A) .. " with " .. #type(B))
    when #type(A) =/=K #type(B)



  // external process helper
  syntax FunctionCall ::= #callHelper(ValueList)
                        | #callHelperImpl(String, ValueList)
                        | "#callHelperExit" "(" ")"
  rule #callHelper(V:ValueList) => #callHelperImpl("nodejs\x01luahelper.js", V:ValueList)
  rule #callHelperImpl(S:String, (V:String, Vs:ValueList)) =>
    #callHelperImpl(S:String +String "\x01" +String V:String, Vs:ValueList)
  rule #callHelperImpl(S:String, .ValueList) => #system(S) ~> #callHelperExit()
  rule #systemResult(E:Int, S:String, W:String) ~> #callHelperExit() => S

  syntax FunctionCall ::= #tonumber(ExpressionList) [strict]
                        | #tonumberImpl(Value) [function]
                        | #tonumberImplString(Expression) [strict]
  rule #tonumber(V:Value, Vs:ValueList) => #tonumberImpl(V:Value)
  rule #tonumber(.ValueList) => nil
  rule #tonumberImpl(F:Float) => F
  rule #tonumberImpl(S:String) => #tonumberImplString(#callHelper("tonumber", S))
  rule #tonumberImplString(S:String) => String2Float(S) when S =/=String ""
  rule #tonumberImplString("") => nil
  rule #tonumberImpl(V:Value) => nil when notBool (isFloat(V) orBool isString(V))



  // type coercion
  syntax FunctionCall ::= #toboolean(ExpressionList) [strict]
                        | #tobooleanImpl(Value) [function]
  rule #toboolean(V:Value, Vs:ValueList) => #tobooleanImpl(V:Value)
  rule #toboolean(.ValueList) => false
  rule #tobooleanImpl(false) => false
  rule #tobooleanImpl(nil) => false
  rule #tobooleanImpl(V:Value) => true when notBool (V ==K false orBool V ==K nil)

  syntax FunctionCall ::= #arithmeticParam(ExpressionList) [strict]
                        | #arithmeticParamImpl(Value) [function]
                        | #arithmeticParamImplString(Expression) [strict]
  rule #arithmeticParam(V:Value, Vs:ValueList) => #arithmeticParamImpl(V:Value)
  rule #arithmeticParam(.ValueList) => #arithmeticError(nil)
  rule #arithmeticParamImpl(F:Float) => F
  rule #arithmeticParamImpl(S:String) => #arithmeticParamImplString(#tonumber(S))
  rule #arithmeticParamImplString(nil) => #arithmeticError("")
  rule #arithmeticParamImplString(F:Float) => F
  rule #arithmeticParamImpl(V:Value) => #arithmeticError(V) when notBool (isFloat(V) orBool isString(V))

  syntax FunctionCall ::= #concatParam(ExpressionList) [strict]
                        | #concatParamImpl(Value) [function]
  rule #concatParam(V:Value, Vs:ValueList) => #concatParamImpl(V:Value)
  rule #concatParam(.ValueList) => #concatError(nil)
  rule #concatParamImpl(S:String) => S
  rule #concatParamImpl(F:Float) => #tostring(F)
  rule #concatParamImpl(V:Value) => #concatError(V) when notBool(isString(V) orBool isFloat(V))

  syntax FunctionCall ::= #bitwiseParam(ExpressionList) [strict]
                        | #bitwiseParamImpl(Value) [function]
                        | #bitwiseParamImplString(Expression) [strict]
  rule #bitwiseParam(V:Value, Vs:ValueList) => #bitwiseParamImpl(V:Value)
  rule #bitwiseParam(.ValueList) => #bitwiseOpError(nil)
  rule #bitwiseParamImpl(F:Float) => floorFloat(F) when F %Float 1.0 ==Float 0.0
  rule #bitwiseParamImpl(F:Float) => #error("number has no integer representation") when F %Float 1.0 =/=Float 0.0
  rule #bitwiseParamImpl(S:String) => #bitwiseParamImplString(#tonumber(S))
  rule #bitwiseParamImplString(nil) => #bitwiseOpError("")
  rule #bitwiseParamImplString(F:Float) => F
  rule #bitwiseParamImpl(V:Value) => #bitwiseOpError(V) when notBool (isFloat(V) orBool isString(V))

  syntax FunctionCall ::= #checkCompareError(Value, Value)
  rule #checkCompareError(A:Float, B:Float) => .
  rule #checkCompareError(A:Value, B:Value) => #compareError(A, B) when notBool(isFloat(A) andBool isFloat(B))



  // power
  syntax FunctionCall ::= #pow(Expression, Expression) [strict]
  rule A:Expression ^ B:Expression => #pow(#arithmeticParam(A), #arithmeticParam(B))
  rule #pow(A:Float, B:Float) => A ^Float B

  // boolean not
  syntax FunctionCall ::= #not(Expression) [strict]
  rule not E:Expression => #not(#toboolean(E:Expression))
  rule #not(B:Bool) => notBool B

  // length
  syntax FunctionCall ::= #len(Expression, Expression) [strict]
  rule # E:Expression => #len(#eval1(E), 1.0)
  rule #len(L:TablePtr, Pos:Float) => #rawget(L, Pos) == nil ~> #len(L, Pos +Float 1.0)
  rule true ~> #len(L:TablePtr, Pos:Float) => Pos -Float 2.0
  rule false ~> #len(L:TablePtr, Pos:Float) => #len(L:TablePtr, Pos:Float)
  rule #len(S:String, Pos:Float) => IntToFloat(lengthString(S))
  rule #len(E:Value, Pos:Float) => #lengthError(E) when notBool(isTablePtr(E) orBool isString(E))

  // unary minus
  syntax FunctionCall ::= #unm(Expression) [strict]
  rule - E:Expression => #unm(#arithmeticParam(E))
  rule #unm(E:Float) => --Float E

  // bitwise not
  syntax FunctionCall ::= #bnot(Expression) [strict]
  rule ~ E:Expression => #bnot(#bitwiseParam(E))
  rule #bnot(E:Float) => IntToFloat(~Int Float2Int(E))

  // multiplication
  syntax FunctionCall ::= #mul(Expression, Expression) [strict]
  rule A:Expression * B:Expression => #mul(#arithmeticParam(A), #arithmeticParam(B))
  rule #mul(A:Float, B:Float) => A *Float B

  // division
  syntax FunctionCall ::= #div(Expression, Expression) [strict]
  rule A:Expression / B:Expression => #div(#arithmeticParam(A), #arithmeticParam(B))
  rule #div(A:Float, B:Float) => A /Float B

  // integer division
  syntax FunctionCall ::= #idiv(Expression, Expression) [strict]
  rule A:Expression / / B:Expression => #idiv(#arithmeticParam(A), #arithmeticParam(B))
  rule #idiv(A:Float, B:Float) => floorFloat(A /Float B)

  // integer division with left param as integer constant
  syntax FunctionCall ::= #iidiv(Expression, Expression) [strict]
  rule A:Expression i/ / B:Expression => #iidiv(#arithmeticParam(A), #arithmeticParam(B))
  rule #iidiv(A:Float, B:Float) => #idiv(A, B) when B =/=Float 0.0
  rule #iidiv(A:Float, 0.0) => #error("attempt to divide by zero")

  // modulo
  syntax FunctionCall ::= #mod(Expression, Expression) [strict]
  rule A:Expression % B:Expression => #mod(#arithmeticParam(A), #arithmeticParam(B))
  rule #mod(A:Float, B:Float) => A -Float floorFloat(A /Float B) *Float B when B =/=Float 0.0
  rule #mod(A:Float, 0.0) => #error("attempt to perform 'n%0'")

  // addition
  syntax FunctionCall ::= #add(Expression, Expression) [strict]
  rule A:Expression + B:Expression => #add(#arithmeticParam(A), #arithmeticParam(B))
  rule #add(A:Float, B:Float) => A +Float B

  // subtraction
  syntax FunctionCall ::= #sub(Expression, Expression) [strict]
  rule A:Expression - B:Expression => #sub(#arithmeticParam(A), #arithmeticParam(B))
  rule #sub(A:Float, B:Float) => A -Float B

  // concatenation
  syntax FunctionCall ::= #concat(Expression, Expression) [strict]
  rule A:Expression .. B:Expression => #concat(#concatParam(A), #concatParam(B))
  rule #concat(A:String, B:String) => A +String B

  // bitwise left shift
  syntax FunctionCall ::= #blshift(Expression, Expression) [strict]
  rule A:Expression << B:Expression => #blshift(#bitwiseParam(A), #bitwiseParam(B))
  rule #blshift(A:Float, B:Float) => IntToFloat(Float2Int(A) <<Int Float2Int(B))    // >

  // bitwise right shift
  syntax FunctionCall ::= #brshift(Expression, Expression) [strict]
  rule A:Expression >> B:Expression => #brshift(#bitwiseParam(A), #bitwiseParam(B))
  rule #brshift(A:Float, B:Float) => IntToFloat(Float2Int(A) >>Int Float2Int(B))

  // bitwise and
  syntax FunctionCall ::= #band(Expression, Expression) [strict]
  rule A:Expression & B:Expression => #band(#bitwiseParam(A), #bitwiseParam(B))
  rule #band(A:Float, B:Float) => IntToFloat(Float2Int(A) &Int Float2Int(B))

  // bitwise xor
  syntax FunctionCall ::= #bxor(Expression, Expression) [strict]
  rule A:Expression ~ B:Expression => #bxor(#bitwiseParam(A), #bitwiseParam(B))
  rule #bxor(A:Float, B:Float) => IntToFloat(Float2Int(A) xorInt Float2Int(B))

  // bitwise or
  syntax FunctionCall ::= #bor(Expression, Expression) [strict]
  rule A:Expression | B:Expression => #bor(#bitwiseParam(A), #bitwiseParam(B))
  rule #bor(A:Float, B:Float) => IntToFloat(Float2Int(A) |Int Float2Int(B))

  // lower than
  syntax FunctionCall ::= #lt(Expression, Expression) [strict]
                        | #ltImpl(Value, Value)
  rule A:Expression < B:Expression => #lt(#eval1(A), #eval1(B))
  rule #lt(A:Value, B:Value) => #checkCompareError(A, B) ~> #ltImpl(A, B)
  rule #ltImpl(A:Float, B:Float) => A <Float B    // >

  // greater than
  rule A:Expression > B:Expression => not (A <= B)

  // lower than or equal
  syntax FunctionCall ::= #le(Expression, Expression) [strict]
                        | #leImpl(Value, Value)
  rule A:Expression <= B:Expression => #le(#eval1(A), #eval1(B))
  rule #le(A:Value, B:Value) => #checkCompareError(A, B) ~> #leImpl(A, B)
  rule #leImpl(A:Float, B:Float) => A <=Float B

  // greater than or equal
  rule A:Expression >= B:Expression => not (A < B)    // >

  // not equal
  rule A:Expression ~= B:Expression => not (A == B)

  // equal
  syntax FunctionCall ::= #eq(Expression, Expression) [strict]
  rule A:Expression == B:Expression => #eq(#eval1(A), #eval1(B))
  rule #eq(A:Value, B:Value) => A ==K B

  // boolean and
  syntax K ::= #andThen(Expression)
  rule A:Expression and B:Expression => #toboolean(A) ~> #andThen(B)
  rule true ~> #andThen(B:Expression) => B
  rule false ~> #andThen(B:Expression) => false

  // boolean or
  syntax K ::= #orThen(Expression)
  rule A:Expression or B:Expression => #toboolean(A) ~> #orThen(B)
  rule true ~> #orThen(B:Expression) => true
  rule false ~> #orThen(B:Expression) => B
endmodule
