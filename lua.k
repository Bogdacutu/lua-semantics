module LUA-SYNTAX
  syntax Id ::= r"(?<![A-Za-z0-9\\_])[A-Za-z\\_][A-Za-z0-9\\_]*" [token, autoReject, avoid]

  syntax Nil ::= "nil"
  syntax Varargs ::= "..."

  syntax Block ::= Statements ReturnStatement
                 | Statements
                 > Statement

  syntax Statement ::= ";"
                     | VarList "=" NeExpressionList
                     | FunctionCall
                     | "break"
                     | "do" Block "end"
                     | "while" Expression "do" Block "end"
                     | "repeat" Block "until" Expression
                     | "if" Expression "then" Block EndIf [strict(1)]
                     | "for" Id "=" Expression "," Expression "do" Block "end"
                     | "for" Id "=" Expression "," Expression "," Expression "do" Block "end"
                     | "for" IdList "in" NeExpressionList "do" Block "end"
                     | "function" FuncName FuncBody
                     | "local" IdList
                     | "local" IdList "=" NeExpressionList
  syntax Statements ::= List{Statement, " "} [klabel(Statements)]

  syntax EndIf ::= "end"
                 | "else" Block "end"
                 > "elseif" Expression "then" Block EndIf

  syntax FuncName ::= IdDotList
                    | IdDotList ":" Id

  syntax IdList ::= NeList{Id, ","}
  syntax IdDotList ::= NeList{Id, "."}

  syntax ReturnStatement ::= "return" ExpressionList
                           > ReturnStatement ";"

  syntax Literal ::= Nil | Bool | Float | String

  syntax Expression ::= Literal
                      | PrefixExpression
                      | TableConstructor
                      | "function" FuncBody
                      | Varargs
                      > Expression "^" Expression
                      > "not" Expression [left, strict]
                      | "#" Expression [left, strict]
                      | "-" Expression [left, strict]
                      | "~" Expression [left, strict]
                      > Expression "*" Expression [left, strict]
                      | Expression "/" Expression [left, strict]
                      | Expression "//" Expression [left, strict]
                      | Expression "%" Expression [left, strict]
                      > Expression "+" Expression [left, strict]
                      | Expression "-" Expression [left, strict]
                      > Expression ".." Expression [left, strict]
                      > Expression "<<" Expression [left, strict]
                      | Expression ">>" Expression [left, strict]
                      > Expression "&" Expression [left, strict]
                      > Expression "~" Expression [left, strict]
                      > Expression "|" Expression [left, strict]
                      > Expression "<" Expression [left, strict]
                      | Expression ">" Expression [left, strict]
                      | Expression "<=" Expression [left, strict]
                      | Expression ">=" Expression [left, strict]
                      | Expression "~=" Expression [left, strict]
                      | Expression "==" Expression [left, strict]
                      > Expression "and" Expression [left, strict]
                      > Expression "or" Expression [left, strict]
  syntax ExpressionList ::= List{Expression, ","} [klabel(ExpressionList)]
  syntax NeExpressionList ::= NeList{Expression, ","} [klabel(NeExpressionList)]

  syntax PrefixExpression ::= Var
                            | FunctionCall
                            | "(" Expression ")" [bracket]

  syntax FunctionCall ::= FunctionRef "(" ExpressionList ")"
  syntax FunctionRef ::= PrefixExpression
                       | PrefixExpression ":" Id

  syntax FuncBody ::= "(" ParamList ")" Block "end"
  syntax ParamList ::= Varargs
                     | Id
                     > Id "," ParamList

  syntax Var ::= Id
               | PrefixExpression "[" Expression "]" [strict(2)]
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
                    local _ENV = {}
                    ~> (_G = _ENV):Statement
                    ~> function print(...) #print(...) end
                    ~> $PGM:Block
                  </k>
                  <env> .Map </env>
                  <store> .Map </store>
                  <heap> .Map </heap>
                  <fstack> .List </fstack>
                  <out stream="stdout"> .List </out>
                  <keepVar> false </keepVar>
                </T>

  syntax Literal ::= TablePtr | FuncPtr
  syntax KResult ::= Literal

  // tables
  syntax TablePtr ::= "Table" "<" Int ">"

  rule <k> {} => Table<!L:Int> ...</k>
       <heap> M:Map => M[!L <- .Map] </heap>

  syntax KItem ::= "#buildTable" "(" Expression "," Expression "," FieldList ")" [strict(1, 2)]
  rule {... S:FieldSep => . }
  rule { L:FieldList } => #buildTable({}, 1, L)
  rule #buildTable(T:TablePtr, Pos:Float, V:Expression _:FieldSep Ls:FieldList) => #set(T, Pos, V) ~> #buildTable(T, Pos + 1, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, V:Expression) => #set(T, Pos, V) ~> T
  rule #buildTable(T:TablePtr, Pos:Float, K:Id = V:Expression _:FieldSep Ls:FieldList) => #set(T, Id2String(K), V) ~> #buildTable(T, Pos, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, K:Id = V:Expression) => #set(T, Id2String(K), V) ~> T

  // statements
  rule S:Statement Ss:Statements => S ~> Ss
  rule .Statements => .
  rule .Statements R:ReturnStatement => R

  // functions
  syntax FuncPtr ::= "Func" "<" Int ">"
  syntax FuncDef ::= "FuncDef" "<" ParamList "," Block ">"
                   | "FuncDef" "<" Block ">"

  rule <k> function(Args:ParamList) Block:Block end => Func<!L:Int> ...</k>
       <heap> M:Map => M[!L <- FuncDef<Args, Block>] </heap>

  rule function (Name:IdDotList : Ns:Id):FuncName (Args:ParamList) Body:Block end => function Name . Ns (self, Args:ParamList) Body end
  rule function Name:Id Body:FuncBody => #varSet(Name, function Body)
  rule <k> function Name:IdDotList Body:FuncBody => #idDotListToVar(Name:IdDotList) ~> #varSetf1(function Body) ...</k>
       <keepVar> _ => true </keepVar>

  syntax FunctionCall ::= "#idDotListToVar" "(" IdDotList ")"
                        | "#idDotListToVar_" "(" IdDotList "," Var ")"
  rule #idDotListToVar(N:Id . Ns:IdDotList) => #idDotListToVar_(Ns, N)
  rule #idDotListToVar_((N:Id . Ns:IdDotList), V:Var) => #idDotListToVar_(Ns, (V . N))
  rule #idDotListToVar_(.IdDotList, V:Var) => V

  syntax FunctionCall ::= "#reverseList" "(" ExpressionList ")"
                        | "#reverseList_" "(" ExpressionList "," ExpressionList ")"
  rule #reverseList(I) => #reverseList_(I, .ExpressionList)
  rule #reverseList_((I:Expression, Is:ExpressionList), J) => #reverseList_(Is, (I:Expression, J:ExpressionList))
  rule #reverseList_(.ExpressionList, J) => J

  // evaluating single expression
  syntax KItem ::= "#eval" "(" Expression ")"
                 | "#eval_" "(" ")"
  rule #eval(E) => E ~> #eval_()
  rule E:ExpressionList ~> #eval_() => E
  rule E:Literal ~> #eval_() => (E, .ExpressionList)

  // evaluating multiple expressions
  syntax FunctionCall ::= "#evalList" "(" ExpressionList ")"
                        | "#evalList_f0" "(" ")"
                        | "#evalListne" "(" NeExpressionList ")"
                        | "#evalList_f2" "(" ExpressionList "," ExpressionList ")"
                        | "#evalList_f3" "(" ExpressionList ")"
  rule #evalList(.ExpressionList) => .ExpressionList
  rule #evalList(N:Expression, Ns:ExpressionList) => #eval(N) ~> #evalList_f2(Ns, .ExpressionList)
  rule V:ExpressionList ~> #evalList_f2(N:ExpressionList, R:ExpressionList) => #concatList(R:ExpressionList, V:ExpressionList) ~> #evalList_f3(N)
  rule R:ExpressionList ~> #evalList_f3(N:Expression, Ns:ExpressionList) => #eval(N) ~> #evalList_f2(Ns, R)
  rule R:ExpressionList ~> #evalList_f3(.ExpressionList) => R
  rule V:ExpressionList ~> #evalList_f0() => #evalList(V:ExpressionList)
  rule #evalListne(V:NeExpressionList) => #neExprListToExprList(V) ~> #evalList_f0()

  syntax FunctionCall ::= "#concatList" "(" ExpressionList "," ExpressionList ")"
                        | "#concatList_" "(" ExpressionList "," ExpressionList ")"
                        | "#concatList_f1" "(" ExpressionList ")"
  rule #concatList(A:ExpressionList, B:ExpressionList) => #reverseList(A) ~> #concatList_f1(B)
  rule A:ExpressionList ~> #concatList_f1(B:ExpressionList) => #concatList_(A, B)
  rule #concatList_((A:Expression, As:ExpressionList), B:ExpressionList) => #concatList_(As, (A:Expression, B:ExpressionList))
  rule #concatList_(.ExpressionList, B:ExpressionList) => B

  // variable set
  syntax FunctionCall ::= "#neExprListToExprList" "(" NeExpressionList ")"
                        | "#neExprListToExprList_" "(" NeExpressionList "," ExpressionList ")"
  rule #neExprListToExprList(L) => #neExprListToExprList_(L, .ExpressionList)
  rule #neExprListToExprList_((A:Expression, As:NeExpressionList), B:ExpressionList) => #neExprListToExprList_(As, (A:Expression, B:ExpressionList))
  rule #neExprListToExprList_(.NeExpressionList, B:ExpressionList) => #reverseList(B)

  syntax FunctionCall ::= "#varSetList" "(" VarList "," NeExpressionList ")"
                        | "#varSetList_" "(" VarList "," ExpressionList ")"
                        | "#varSetList_f0" "(" VarList ")"
  rule N:VarList = V:NeExpressionList => #varSetList(N, V:NeExpressionList)
  rule #varSetList(N, V) => #evalListne(V) ~> #varSetList_f0(N)
  rule V:ExpressionList ~> #varSetList_f0(N:VarList) => #varSetList_(N, V)
  rule #varSetList_((N:Var, Ns:VarList), (V:Expression, Vs:ExpressionList)) => #varSet(N, V) ~> #varSetList_(Ns, Vs)
  rule #varSetList_(.VarList, V:ExpressionList) => .
  rule #varSetList_((N:Var, Ns:VarList), .ExpressionList) => #varSetList_((N:Var, Ns:VarList), (nil, .ExpressionList))

  syntax FunctionCall ::= "#varSet" "(" Var "," Expression ")" [strict(2)]
                        | "#varSetf1" "(" Expression ")"
  rule #varSet(N:Id, V:Expression) => #varSetlocal(Id2String(N), V:Expression)
  rule <k> N:Var ~> #varSetf1(V:Expression) => #varSet(N, V) ...</k>
       <keepVar> true => false </keepVar>

  syntax FunctionCall ::= "#varSetlocal" "(" String "," Expression ")" [strict(2)]
                        | "#varSetlocal" "(" String "," ExpressionList ")"
  rule <k> #varSetlocal(N, V:Expression) => . ...</k>
       <env>... N |-> L:Int ...</env>
       <store>... L |-> (_ => V) ...</store>
  rule <k> #varSetlocal(N, V:ExpressionList) => . ...</k>
       <env>... N |-> L:Int ...</env>
       <store>... L |-> (_ => V) ...</store> // special case for varargs
  rule <k> #varSetlocal(N, V) => #set(_ENV, N, V) ...</k>
       <env> M </env> when notBool(N in keys(M))

  syntax FunctionCall ::= "#defineLocal" "(" String ")"
  rule <k> #defineLocal(N) => . ...</k>
       <env> M => M[N <- !L:Int] </env>
       <store> R => R[!L <- nil] </store>

  syntax FunctionCall ::= "#defineAndSetLocalList" "(" IdList "," NeExpressionList ")"
                        | "#defineAndSetLocalList_f0" "(" IdList ")"
                        | "#defineAndSetLocalList_" "(" IdList "," ExpressionList ")"
  rule local N:IdList = V:NeExpressionList => #defineAndSetLocalList(N, V)
  rule #defineAndSetLocalList(N, V) => #evalListne(V) ~> #defineAndSetLocalList_f0(N)
  rule V:ExpressionList ~> #defineAndSetLocalList_f0(N:IdList) => #defineAndSetLocalList_(N, V)
  rule #defineAndSetLocalList_((N:Id, Ns:IdList), (V:Expression, Vs:ExpressionList)) => #defineLocal(Id2String(N)) ~> #varSetlocal(Id2String(N), V) ~> #defineAndSetLocalList_(Ns, Vs)
  rule #defineAndSetLocalList_(.IdList, V:ExpressionList) => .
  rule #defineAndSetLocalList_((N:Id, Ns:IdList), .ExpressionList) => #defineAndSetLocalList_((N:Id, Ns:IdList), (nil, .ExpressionList))

  // variable get
  rule <k> Name:Id => V ...</k>
       <env>... Id2String(Name) |-> L:Int ...</env>
       <store>... L |-> V ...</store>
       <keepVar> false </keepVar>
  rule <k> Name:Id => #get(_ENV, Id2String(Name)) ...</k>
       <keepVar> false </keepVar>
       <env> M </env> when notBool(Id2String(Name) in keys(M))
  rule <k> (...):Varargs => V ...</k>
       <env>... "..." |-> L:Int ...</env>
       <store>... L |-> V ...</store>

  rule E:PrefixExpression [ K:Expression ] => #get(E, K)
  rule (E:PrefixExpression . K:Id):Var => #get(E, Id2String(K))

  // builtin set
  syntax FunctionCall ::= "#set" "(" Expression "," Expression "," Expression ")" [strict]
  syntax FunctionCall ::= "#rawset" "(" Expression "," Expression "," Expression ")" [strict]
  rule #set(T, N, V) => #rawset(T, N, V)
  rule <k> #rawset(Table<T:Int>, Name, Value) => . ...</k>
       <heap>... T |-> (M:Map => M[Name <- Value]) ...</heap>

  // builtin get
  syntax FunctionCall ::= "#get" "(" Expression "," Expression ")" [strict]
  syntax FunctionCall ::= "#rawget" "(" Expression "," Expression ")" [strict]
  rule #get(T, N) => #rawget(T, N)
  rule <k> #rawget(Table<T:Int>, Name) => M:Map[Name] ...</k>
       <heap>... T |-> M:Map ...</heap> when Name in keys(M)
  rule <k> #rawget(Table<T:Int>, Name) => nil ...</k>
       <heap>... T |-> M:Map ...</heap> when notBool(Name in keys(M))

  // builtin print
  syntax FunctionCall ::= "#print" "(" ExpressionList ")"
                        | "#print_" "(" Expression ")" [strict]
                        | "#print_2" "(" ExpressionList ")"
                        | "#print_2f" "(" ")"
  rule #print_2(E:Expression, Es:ExpressionList) => #print_(#tostring(E)) ~> #print_(" ") ~> #print_2(Es)
  rule #print_2(.ExpressionList) => #print_("\n")
  rule #print(L) => #evalList(L) ~> #print_2f()
  rule L:ExpressionList ~> #print_2f() => #print_2(L)
  rule <k> #print_(S:String) => . ...</k>
       <out>... . => ListItem(S) </out>

  syntax FunctionCall ::= "#tostring" "(" Expression ")" [strict]
  rule #tostring(S:String) => S
  rule #tostring(N:Float) => Int2String(Float2Int(N)) when N %Float 1.0 ==Float 0.0
  rule #tostring(N:Float) => Float2String(N) when N %Float 1.0 =/=Float 0.0
  rule #tostring(nil) => "nil"

  // function call
  syntax FunctionCall ::= "#call" "(" FunctionRef "," ExpressionList ")"
                        | "#call_" "(" Expression "," ExpressionList ")" [strict(1)]
                        | "#call_f2" "(" Expression ")"
                        | "#call_" "(" FuncDef "," ExpressionList ")"
  rule F:FunctionRef(Args:ExpressionList) => #call(F, Args)
  rule #call(E:PrefixExpression : Es:Id, Args:ExpressionList) => #call((E . Es), (E:PrefixExpression, Args:ExpressionList))
  rule #call(E:PrefixExpression, Args:ExpressionList) => #evalList(Args) ~> #call_f2(E)
  rule E:ExpressionList ~> #call_f2(F:Expression) => #call_(F, E)
  rule <k> #call_(Func<L:Int>, Args:ExpressionList) => #enter(CallFrame, #call_(M:FuncDef, Args)) ...</k>
       <heap>... L |-> M:FuncDef ...</heap>
  rule #call_(FuncDef<(N:Id, Ns:ParamList), B:Block>, (Arg:Expression, Args:ExpressionList)) =>
    #defineLocal(Id2String(N)) ~> #varSetlocal(Id2String(N), Arg) ~> #call_(FuncDef<Ns, B>, Args)
  rule #call_(FuncDef<N:Id, B:Block>, (Arg:Expression, Args:ExpressionList)) =>
    #defineLocal(Id2String(N)) ~> #varSetlocal(Id2String(N), Arg) ~> #call_(FuncDef<B>, Args)
  rule #call_(FuncDef<(...):Varargs, B:Block>, Args:ExpressionList) =>
    #defineLocal("...") ~> #varSetlocal("...", Args:ExpressionList) ~> #call_(FuncDef<B>, .ExpressionList)
  rule #call_(FuncDef<B:Block>, Args:ExpressionList) => B

  syntax StackFrame ::= "StackFrame" "<" FrameType "," Map "," K ">"
  syntax FrameType ::= "CallFrame" | "LoopFrame" | "ScopeFrame"
  syntax KItem ::= "#enter" "(" FrameType "," K ")"
  rule <k> (#enter(T:FrameType, B) ~> Rest) => B </k>
       <env> M => M["..." <- nil] </env>
       <fstack> .List => ListItem(StackFrame<T, M, Rest>) ...</fstack>
  syntax KItem ::= "#return" "(" FrameType "," ExpressionList ")"
                 | "#return" "(" FrameType ")"
                 | "#return_" "(" FrameType "," ExpressionList ")"
                 | "#return_" "(" FrameType ")"
                 | "#return_f2" "(" FrameType ")"
  rule #return(T:FrameType, E:ExpressionList) => #evalList(E) ~> #return_f2(T)
  rule #return(T:FrameType) => #return_(T)
  rule E:ExpressionList ~> #return_f2(T:FrameType) => #return_(T, E:ExpressionList)
  rule <k> #return_(T:FrameType, E:ExpressionList) => #return_(T:FrameType, E:ExpressionList) </k>
       <fstack> ListItem(StackFrame<Type, M, Rest>) => .List ...</fstack> when Type =/=K T
  rule <k> #return_(T:FrameType, E:ExpressionList) => E ~> Rest </k>
       <fstack> ListItem(StackFrame<T, M, Rest>) => .List ...</fstack>
  rule <k> #return_(T:FrameType) => #return_(T:FrameType) </k>
       <fstack> ListItem(StackFrame<Type, M, Rest>) => .List ...</fstack> when Type =/=K T
  rule <k> #return_(T:FrameType) => Rest </k>
       <fstack> ListItem(StackFrame<T, M, Rest>) => .List ...</fstack>
  rule <k> . => Rest </k>
       <env> _ => M </env>
       <fstack> ListItem(StackFrame<T, M, Rest>) => .List ...</fstack>

  // math
  rule A:Float + B:Float => A +Float B

  syntax FunctionCall ::= "#concat" "(" Expression "," Expression ")" [strict]
                        | "#concat_" "(" Expression "," Expression ")" [strict]
  rule A:Literal .. B:Literal => #concat(A, B)
  rule #concat(A, B) => #concat_(#tostring(A), #tostring(B))
  rule #concat_(A:String, B:String) => A +String B

  rule not A:Bool => notBool A
  rule A:Bool or B:Bool => A orBool B

  rule A:Float < B:Float => A <Float B

  syntax FunctionCall ::= "#equal" "(" Expression "," Expression ")" [strict]
                        | "#rawequal" "(" Expression "," Expression ")" [strict]
  rule A:Literal == B:Literal => #equal(A, B)
  rule #equal(A, B) => #rawequal(A, B)
  rule #rawequal(A:Literal, B:Literal) => A ==K B

  rule A:Literal <= B:Literal => (A == B) or (A < B)
  rule A:Literal ~= B:Literal => not (A == B)

  syntax FunctionCall ::= "#len_" "(" TablePtr "," Expression ")" [strict]
                        | "#len_f" "(" TablePtr "," Expression ")"
  rule # L:TablePtr => #len_(L, 0)
  rule #len_(L:TablePtr, Pos:Float) => #get(L, Pos +Float 1) == nil ~> #len_f(L, Pos)
  rule true ~> #len_f(L:TablePtr, Pos:Float) => Pos
  rule false ~> #len_f(L:TablePtr, Pos:Float) => #len_(L, Pos +Float 1)

  syntax FunctionCall ::= "#tobool" "(" Expression ")" [strict]
  rule #tobool(false) => false
  rule #tobool(nil) => false
  rule #tobool(L:Literal) => true when notBool(L ==K false orBool L ==K nil)

  // return
  rule R:ReturnStatement ; => R
  rule return E:ExpressionList => #return(CallFrame, E:ExpressionList)

  // if -- TODO: tobool
  rule if true then B:Block E:EndIf => #enter(ScopeFrame, B)
  rule if false then _:Block E:EndIf => E
  rule else B:Block end => #enter(ScopeFrame, B)
  rule elseif E:Expression then B:Block F:EndIf => if E then B F
  rule end => .

  // do
  rule do B:Block end => #enter(ScopeFrame, B)

  // while
  syntax KItem ::= "#while" "(" Expression "," Block ")"
                 | "#while_f" "(" Expression "," Block ")"
  rule while E:Expression do B:Block end => #enter(LoopFrame, #while(E, B))
  rule #while(E:Expression, B:Block) => #tobool(E) ~> #while_f(E, B)
  rule true ~> #while_f(E:Expression, B:Block) => #enter(ScopeFrame, B) ~> #while(E, B)
  rule false ~> #while_f(E:Expression, B:Block) => .
  rule break => #return(LoopFrame)
endmodule
