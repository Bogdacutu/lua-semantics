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
                      > "not" Expression
                      > Expression "+" Expression [left, strict]
                      > Expression ".." Expression [left, strict]
                      > Expression "<" Expression [left, strict]
                      | Expression "==" Expression [left, strict]
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
               | PrefixExpression "[" Expression "]"
               | PrefixExpression "." Id
  syntax VarList ::= NeList{Var, ","}

  syntax TableConstructor ::= "{" "}"
endmodule

module LUA
  imports LUA-SYNTAX
  imports FLOAT

  configuration <T>
                  <k>
                    #defineEnv({})
                    ~> _G = _ENV
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

  // runtime
  syntax FunctionCall ::= "#defineEnv" "(" Expression ")" [strict]
  rule <k> #defineEnv(Env:TablePtr) => . ...</k>
       <store> N:Map => N[!L:Int <- Env] </store>
       <env> M:Map => M["_ENV" <- !L] </env>

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
  rule function Name:Id Body:FuncBody => #varset(Name, function Body)
  rule <k> function Name:IdDotList Body:FuncBody => #idDotListToVar(Name:IdDotList) ~> #varsetf1(function Body) ...</k>
       <keepVar> _ => true </keepVar>

  syntax FunctionCall ::= "#idDotListToVar" "(" IdDotList ")"
                        | "#idDotListToVar_" "(" IdDotList "," Var ")"
  rule #idDotListToVar(N:Id . Ns:IdDotList) => #idDotListToVar_(Ns, N)
  rule #idDotListToVar_((N:Id . Ns:IdDotList), V:Var) => #idDotListToVar_(Ns, (V . N))
  rule #idDotListToVar_(.IdDotList, V:Var) => V

  syntax FunctionCall ::= "#reverselist" "(" ExpressionList ")"
                        | "#reverselist_" "(" ExpressionList "," ExpressionList ")"
  rule #reverselist(I) => #reverselist_(I, .ExpressionList)
  rule #reverselist_((I:Expression, Is:ExpressionList), J) => #reverselist_(Is, (I:Expression, J:ExpressionList))
  rule #reverselist_(.ExpressionList, J) => J

  // dereferencing single expression
  syntax KItem ::= "#deref" "(" Expression ")"
                 | "#deref_" "(" ")"
  rule #deref(E) => E ~> #deref_()
  rule E:ExpressionList ~> #deref_() => E
  rule E:Literal ~> #deref_() => (E, .ExpressionList)

  // dereferencing multiple expressions
  syntax FunctionCall ::= "#dereflist" "(" ExpressionList ")"
                        | "#dereflist_f0" "(" ")"
                        | "#dereflistne" "(" NeExpressionList ")"
                        | "#dereflist_f2" "(" ExpressionList "," ExpressionList ")"
                        | "#dereflist_f3" "(" ExpressionList ")"
  rule #dereflist(.ExpressionList) => .ExpressionList
  rule #dereflist(N:Expression, Ns:ExpressionList) => #deref(N) ~> #dereflist_f2(Ns, .ExpressionList)
  rule V:ExpressionList ~> #dereflist_f2(N:ExpressionList, R:ExpressionList) => #concatlist(R:ExpressionList, V:ExpressionList) ~> #dereflist_f3(N)
  rule R:ExpressionList ~> #dereflist_f3(N:Expression, Ns:ExpressionList) => #deref(N) ~> #dereflist_f2(Ns, R)
  rule R:ExpressionList ~> #dereflist_f3(.ExpressionList) => R
  rule V:ExpressionList ~> #dereflist_f0() => #dereflist(V:ExpressionList)
  rule #dereflistne(V:NeExpressionList) => #neexprlisttoexprlist(V) ~> #dereflist_f0()

  syntax FunctionCall ::= "#concatlist" "(" ExpressionList "," ExpressionList ")"
                        | "#concatlist_" "(" ExpressionList "," ExpressionList ")"
                        | "#concatlist_f1" "(" ExpressionList ")"
  rule #concatlist(A:ExpressionList, B:ExpressionList) => #reverselist(A) ~> #concatlist_f1(B)
  rule A:ExpressionList ~> #concatlist_f1(B:ExpressionList) => #concatlist_(A, B)
  rule #concatlist_((A:Expression, As:ExpressionList), B:ExpressionList) => #concatlist_(As, (A:Expression, B:ExpressionList))
  rule #concatlist_(.ExpressionList, B:ExpressionList) => B

  // variable set
  syntax FunctionCall ::= "#neexprlisttoexprlist" "(" NeExpressionList ")"
                        | "#neexprlisttoexprlist_" "(" NeExpressionList "," ExpressionList ")"
  rule #neexprlisttoexprlist(L) => #neexprlisttoexprlist_(L, .ExpressionList)
  rule #neexprlisttoexprlist_((A:Expression, As:NeExpressionList), B:ExpressionList) => #neexprlisttoexprlist_(As, (A:Expression, B:ExpressionList))
  rule #neexprlisttoexprlist_(.NeExpressionList, B:ExpressionList) => #reverselist(B)

  syntax FunctionCall ::= "#varsetlist" "(" VarList "," NeExpressionList ")"
                        | "#varsetlist_" "(" VarList "," ExpressionList ")"
                        | "#varsetlist_f0" "(" VarList ")"
  rule N:VarList = V:NeExpressionList => #varsetlist(N, V:NeExpressionList)
  rule #varsetlist(N, V) => #dereflistne(V) ~> #varsetlist_f0(N)
  rule V:ExpressionList ~> #varsetlist_f0(N:VarList) => #varsetlist_(N, V)
  rule #varsetlist_((N:Var, Ns:VarList), (V:Expression, Vs:ExpressionList)) => #varset(N, V) ~> #varsetlist_(Ns, Vs)
  rule #varsetlist_(.VarList, V:ExpressionList) => .
  rule #varsetlist_((N:Var, Ns:VarList), .ExpressionList) => #varsetlist_((N:Var, Ns:VarList), (nil, .ExpressionList))

  syntax FunctionCall ::= "#varset" "(" Var "," Expression ")" [strict(2)]
                        | "#varsetf1" "(" Expression ")"
  rule #varset(N:Id, V:Expression) => #varsetlocal(Id2String(N), V:Expression)
  rule <k> N:Var ~> #varsetf1(V:Expression) => #varset(N, V) ...</k>
       <keepVar> true => false </keepVar>

  syntax FunctionCall ::= "#varsetlocal" "(" String "," Expression ")" [strict(2)]
                        | "#varsetlocal" "(" String "," ExpressionList ")"
  rule <k> #varsetlocal(N, V:Expression) => . ...</k>
       <env>... N |-> L:Int ...</env>
       <store>... L |-> (_ => V) ...</store>
  rule <k> #varsetlocal(N, V:ExpressionList) => . ...</k>
       <env>... N |-> L:Int ...</env>
       <store>... L |-> (_ => V) ...</store> // special case for varargs
  rule <k> #varsetlocal(N, V) => #set(_ENV, N, V) ...</k>
       <env> M </env> when notBool(N in keys(M))

  syntax FunctionCall ::= "#definelocal" "(" String ")"
  rule <k> #definelocal(N) => . ...</k>
       <env> M => M[N <- !L:Int] </env>
       <store> R => R[!L <- nil] </store>

  syntax FunctionCall ::= "#defineandsetlocallist" "(" IdList "," NeExpressionList ")"
                        | "#defineandsetlocallist_f0" "(" IdList ")"
                        | "#defineandsetlocallist_" "(" IdList "," ExpressionList ")"
  rule local N:IdList = V:NeExpressionList => #defineandsetlocallist(N, V)
  rule #defineandsetlocallist(N, V) => #dereflistne(V) ~> #defineandsetlocallist_f0(N)
  rule V:ExpressionList ~> #defineandsetlocallist_f0(N:IdList) => #defineandsetlocallist_(N, V)
  rule #defineandsetlocallist_((N:Id, Ns:IdList), (V:Expression, Vs:ExpressionList)) => #definelocal(Id2String(N)) ~> #varsetlocal(Id2String(N), V) ~> #defineandsetlocallist_(Ns, Vs)
  rule #defineandsetlocallist_(.IdList, V:ExpressionList) => .
  rule #defineandsetlocallist_((N:Id, Ns:IdList), .ExpressionList) => #defineandsetlocallist_((N:Id, Ns:IdList), (nil, .ExpressionList))

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
       <heap>... T |-> M:Map ...</heap>

  // builtin print
  syntax FunctionCall ::= "#print" "(" ExpressionList ")"
                        | "#print_" "(" Expression ")" [strict]
                        | "#print_2" "(" ExpressionList ")"
                        | "#print_2f" "(" ")"
  rule #print_2(E:Expression, Es:ExpressionList) => #print_(#tostring(E)) ~> #print_(" ") ~> #print_2(Es)
  rule #print_2(.ExpressionList) => #print_("\n")
  rule #print(L) => #dereflist(L) ~> #print_2f()
  rule L:ExpressionList ~> #print_2f() => #print_2(L)
  rule <k> #print_(S:String) => . ...</k>
       <out>... . => ListItem(S) </out>

  syntax FunctionCall ::= "#tostring" "(" Expression ")" [strict]
  rule #tostring(S:String) => S
  rule #tostring(N:Float) => Int2String(Float2Int(N)) when N %Float 1.0 ==Float 0.0
  rule #tostring(N:Float) => Float2String(N) when N %Float 1.0 =/=Float 0.0

  // function call
  syntax FunctionCall ::= "#call" "(" FunctionRef "," ExpressionList ")"
                        | "#call_" "(" Expression "," ExpressionList ")" [strict(1)]
                        | "#call_" "(" FuncDef "," ExpressionList ")"
  rule F:FunctionRef(Args:ExpressionList) => #call(F, Args)
  rule #call(E:PrefixExpression : Es:Id, Args:ExpressionList) => #call((E . Es), (E:PrefixExpression, Args:ExpressionList))
  rule #call(E:PrefixExpression, Args:ExpressionList) => #call_(E, Args)
  rule <k> #call_(Func<L:Int>, Args:ExpressionList) => #pushFuncCall ~> #call_(M:FuncDef, Args) ~> #popFuncCall ...</k>
       <heap>... L |-> M:FuncDef ...</heap>
  rule #call_(FuncDef<(N:Id, Ns:ParamList), B:Block>, (Arg:Expression, Args:ExpressionList)) =>
    #definelocal(Id2String(N)) ~> #varsetlocal(Id2String(N), Arg) ~> #call_(FuncDef<Ns, B>, Args)
  rule #call_(FuncDef<N:Id, B:Block>, (Arg:Expression, Args:ExpressionList)) =>
    #definelocal(Id2String(N)) ~> #varsetlocal(Id2String(N), Arg) ~> #call_(FuncDef<B>, Args)
  rule #call_(FuncDef<(...):Varargs, B:Block>, Args:ExpressionList) =>
    #definelocal("...") ~> #varsetlocal("...", Args:ExpressionList) ~> #call_(FuncDef<B>, .ExpressionList)
  rule #call_(FuncDef<B:Block>, Args:ExpressionList) => B

  syntax KItem ::= "#pushFuncCall" | "#popFuncCall"
  rule <k> #pushFuncCall => . ...</k>
       <env> M => M["..." <- nil] </env>
       <fstack> .List => ListItem(M) ...</fstack>
  rule <k> #popFuncCall => . ...</k>
       <env> _ => M </env>
       <fstack> ListItem(M) => .List ...</fstack>

  // math
  rule A:Float + B:Float => A +Float B

  syntax FunctionCall ::= "#concat" "(" Expression "," Expression ")" [strict]
                        | "#concat_" "(" Expression "," Expression ")" [strict]
  rule A:Literal .. B:Literal => #concat(A, B)
  rule #concat(A, B) => #concat_(#tostring(A), #tostring(B))
  rule #concat_(A:String, B:String) => A +String B

  rule not A:Bool => notBool A

  rule A:Float < B:Float => A <Float B
  rule A:Float == B:Float => A ==Float B

  // return
  syntax KItem ::= "#return_f1"
  rule R:ReturnStatement ~> S:Statement => R
  rule R:ReturnStatement ; => R
  rule return E:ExpressionList ~> #popFuncCall => #dereflist(E) ~> #return_f1
  rule E:ExpressionList ~> #return_f1 => #popFuncCall ~> E

  // if
  rule if true then B:Block E:EndIf => B
  rule if false then _:Block E:EndIf => E
  rule else B:Block end => B
  rule elseif E:Expression then B:Block F:EndIf => if E then B F
endmodule
