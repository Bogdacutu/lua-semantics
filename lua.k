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
                      > Expression "^" Expression [right]
                      > "not" Expression
                      | "#" Expression
                      | "-" Expression
                      | "~" Expression
                      > Expression "*" Expression [left]
                      | Expression "/" Expression [left]
                      | Expression "/ /" Expression [left] // luakast turns '//' into '/ /'
                      | Expression "i/ /" Expression [left] // luakast turns '[Int] //' into 'i/ /'
                      | Expression "%" Expression [left]
                      > Expression "+" Expression [left]
                      | Expression "-" Expression [left]
                      > Expression ".." Expression [right]
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
                        | FunctionRef TableConstructor
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
                    local _ENV = { coroutine = {}, math = {}, io = {}, string = {}, table = {} }
                    ~> (_G = _ENV):Statement

                    // builtin functions
                    ~> (coroutine.create = function(f) .Statements return #coroutineCreate(f) end):Statement
                    ~> (coroutine.resume = function(t, ...) .Statements return #coroutineResume(t, ...) end):Statement
                    ~> (coroutine.running = function() .Statements return #coroutineRunning() end):Statement
                    ~> (coroutine.status = function(t) .Statements return #coroutineStatus(t) end):Statement
                    ~> (coroutine.yield = function(...) .Statements return #coroutineYield(true, ...) end):Statement
                    ~> (error = function(m) .Statements return #error(m) end):Statement
                    ~> (getmetatable = function(t) .Statements return #getmetatable(t) end):Statement
                    ~> (math.floor = function(x) .Statements return #mathFloor(x) end):Statement
                    ~> (math.sqrt = function(x) .Statements return #mathSqrt(x) end):Statement
                    ~> (next = function(t, i) .Statements return #next(t, i) end):Statement
                    ~> (pcall = function(f, ...) .Statements return #pcall(f, ...) end):Statement
                    ~> (print = function(...) #print(...) .Statements end):Statement
                    ~> (rawget = function(t, k) .Statements return #rawget(t, k) end):Statement
                    ~> (rawset = function(t, k, v) #rawset(t, k, v) .Statements end):Statement
                    ~> (setmetatable = function(t, mt) #setmetatable(t, mt) .Statements return t end):Statement
                    ~> (string.byte = function(s, i, j) .Statements return #stringByte(s, i, j) end):Statement
                    ~> (string.char = function(...) .Statements return #stringChar(...) end):Statement
                    ~> (tonumber = function(o) .Statements return #tonumber(o) end):Statement
                    ~> (tostring = function(o) .Statements return #tostringFunc(o) end):Statement
                    ~> (type = function(o) .Statements return #typeFunc(o) end):Statement

                    ~> $PGM:Statements
                  </k>
                  <env> .Map </env>
                  <store> .Map </store>
                  <heap> .Map </heap>
                  <metatables> .Map </metatables>
                  <fstack> .List </fstack>
                  <cstack> .List </cstack>
                  <out stream="stdout"> .List </out>
                  <freshint> 0 </freshint>
                  <error> . </error>
                </T>

  syntax Value ::= TablePtr | FuncPtr | ThreadPtr
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
             | #buildTableLast(TablePtr, Float, ExpressionList) [strict(3)]
  rule { L:FieldList _:FieldSep } => { L }
  rule { L:FieldList } => #buildTable({}, 1.0, L)
  rule #buildTable(T:TablePtr, Pos:Float, V:Expression _:FieldSep Ls:FieldList) =>
    #set(T, Pos, #eval1(V)) ~> #buildTable(T, Pos +Float 1.0, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, V:Expression) => #buildTableLast(T, Pos, #eval(V))
  rule #buildTable(T:TablePtr, Pos:Float, K:Id = V:Expression _:FieldSep Ls:FieldList) =>
    #set(T, Id2String(K), #eval1(V)) ~> #buildTable(T, Pos, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, K:Id = V:Expression) =>
    #set(T, Id2String(K), #eval1(V)) ~> T
  rule #buildTable(T:TablePtr, Pos:Float, [ K:Expression ] = V:Expression _:FieldSep Ls:FieldList) =>
    #set(T, K, #eval1(V)) ~> #buildTable(T, Pos, Ls)
  rule #buildTable(T:TablePtr, Pos:Float, [ K:Expression ] = V:Expression) =>
    #set(T, K, #eval1(V)) ~> T
  rule #buildTableLast(T:TablePtr, Pos:Float, (V:Value, Vs:ValueList)) =>
    #set(T, Pos, V) ~> #buildTableLast(T, Pos +Float 1.0, Vs)
  rule #buildTableLast(T:TablePtr, Pos:Float, .ValueList) => T

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
  rule function N:IdDotList : M:Id () B:Block end =>
    #assign(#idDotListToVar(N:IdDotList) . M:Id, function (self) B end)
  rule function N:IdDotList : M:Id (Args:ParamList) B:Block end =>
    #assign(#idDotListToVar(N:IdDotList) . M:Id, function (self, Args) B end)
  rule local function Name:Id Body:FuncBody => local Name ~> (Name = function Body):Statement

  syntax Var ::= #idDotListToVar(IdDotList) [function]
               | #idDotListToVarImpl(IdDotList, Var) [function]
  rule #idDotListToVar(N:Id . Ns:IdDotList) => #idDotListToVarImpl(Ns, N)
  rule #idDotListToVarImpl((N:Id . Ns:IdDotList), V:Var) => #idDotListToVarImpl(Ns, (V . N))
  rule #idDotListToVarImpl(.IdDotList, V:Var) => V

  // coroutines
  syntax ThreadPtr ::= "Thread" "<" Int ">"
  syntax ThreadDef ::= "ThreadDef" "<" K "," Map "," List   ">"
                     // ThreadDef   < <k> , <env> , <fstack> >
                     | "ThreadDef" "<running>"
                     | "ThreadDef" "<dead>"

  syntax K ::= "#coroutineInit" "(" ")"
  rule Args:ValueList ~> #coroutineInit() => .

  syntax FunctionCall ::= #coroutineCreate(Expression) [strict]
                        | #coroutineCreateImpl(Value, K) [strict(2)]
  rule #coroutineCreate(V:Value) => #coroutineCreateImpl(V, #freshint())
  rule <k> #coroutineCreateImpl(V:Value, L:Int) => Thread<L> ...</k>
       <heap> M:Map => M[L <- ThreadDef<
           #coroutineInit() ~> #coroutineYield(true, #callEntry(V, #coroutineYield(.ValueList))),
           .Map,
           .List
         >] </heap>

  syntax K ::= #coroutineResumeAfter(ValueList, K) [function]
  rule #coroutineResumeAfter(Args:ValueList, Rest:K) => Args ~> Rest

  syntax K ::= #toThreadDef(K, Map, List)
  rule #toThreadDef(R:K ~> Rest:K, Env:Map, Fstack:List) => ThreadDef<R ~> Rest, Env, Fstack> when R =/=K .::K
  rule #toThreadDef(.::K, Env:Map, Fstack:List) => ThreadDef<dead>

  syntax FunctionCall ::= #coroutineResume(Expression, ExpressionList) [strict]
  rule <k> #coroutineResume(Thread<L:Int>, Args:ValueList) ~> Rest:K => #coroutineResumeAfter(Args, Next) </k>
       <heap>... L:Int |-> (ThreadDef<Next:K, Env:Map, Fstack:List> => ThreadDef<running>) ...</heap>
       <env> CEnv:Map => Env:Map </env>
       <fstack> CFstack:List => Fstack:List </fstack>
       <cstack> .List => (ListItem(ThreadDef<Rest:K, CEnv:Map, CFstack:List>) ListItem(L:Int)) ...</cstack>

  syntax FunctionCall ::= #coroutineYield(ExpressionList) [strict]
  rule <k> #coroutineYield(Args:ValueList) ~> Rest:K => #toThreadDef(Rest:K, CEnv:Map, CFstack:List) ~> #coroutineYield(Args) </k>
       <env> CEnv:Map </env>
       <fstack> CFstack:List </fstack>
  rule <k> T:ThreadDef ~> #coroutineYield(Args:ValueList) => Args ~> Next </k>
       <env> _ => Env:Map </env>
       <fstack> _ => Fstack:List </fstack>
       <cstack> (ListItem(ThreadDef<Next:K, Env:Map, Fstack:List>) ListItem(L:Int)) => .List ...</cstack>
       <heap>... L |-> (ThreadDef<running> => T:ThreadDef) ...</heap>
  rule <k> Rest:K => #coroutineYield(false, Err, .ValueList) </k>
       <fstack> .List </fstack>
       <error> Err:Value => . </error>
  rule <k> #coroutineYield(Args:ValueList) => #error("attempt to yield") ...</k>
       <cstack> .List </cstack>

  syntax FunctionCall ::= #coroutineStatus(Expression) [strict]
  rule <k> #coroutineStatus(Thread<L:Int>) => "suspended" ...</k>
       <heap>... L |-> ThreadDef<_, _, _> ...</heap>
  rule <k> #coroutineStatus(Thread<L:Int>) => "running" ...</k>
       <heap>... L |-> ThreadDef<running> ...</heap>
  rule <k> #coroutineStatus(Thread<L:Int>) => "dead" ...</k>
       <heap>... L |-> ThreadDef<dead> ...</heap>

  syntax FunctionCall ::= "#coroutineRunning" "(" ")"
  rule <k> #coroutineRunning() => (Thread<L>, false, .ValueList) ...</k>
       <cstack> ListItem(_) ListItem(L:Int) ...</cstack>
  rule <k> #coroutineRunning() => (Thread<0>, true, .ValueList) ...</k>
       <cstack> .List </cstack>

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
  rule #evalImpl((E:Expression, Es:ExpressionList), .ValueList, Out:ValueList) =>
    #evalImpl(Es:ExpressionList, E:Expression, (nil, Out:ValueList))
  rule #evalImpl((E:Expression, Es:ExpressionList), R:Value, Out:ValueList) =>
    #evalImpl(Es:ExpressionList, E:Expression, (R:Value, Out:ValueList))
  rule #evalImpl((E:Expression, Es:ExpressionList), (R:Value, Rs:ValueList), Out:ValueList) =>
    #evalImpl(Es:ExpressionList, E:Expression, (R:Value, Out:ValueList))
  rule #evalImpl(.ExpressionList, .ValueList, Out:ValueList) =>
    #evalImpl(.ExpressionList, (nil, .ValueList), Out:ValueList)
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
  rule F:FunctionRef T:TableConstructor => #call(F, (T, .ExpressionList))

  rule #call(E:PrefixExpression : Es:Id, Args:ValueList) => #call((E . Es), #eval(#eval1(E), Args))
  rule #call(E:PrefixExpression, Args:ValueList) => #callEntry(E, Args)

  rule <k> #callEntry(Func<L:Int>, Args:ValueList) =>
              #enter(CallFrame, #callEntry(M:FuncDef, Args) ~> return) ...</k>
       <heap>... L |-> M:FuncDef ...</heap>
  rule #callEntry(F:Value, Args:ValueList) =>
    #metatableGet(F, "__call") ~> #callEntry(F, Args) when notBool isFuncPtr(F)
  rule nil ~> #callEntry(F:Value, Args:ValueList) =>
    #error("attempt to call a " +String #type(F) +String " value")
  rule E:Value ~> #callEntry(F:Value, Args:ValueList) =>
    #callEntry(E, (F, Args:ValueList)) when E =/=K nil
  rule #callEntry(FuncDef<P:ParamList, B:Block, Env:Map>, Args:ValueList) =>
    #setEnv(Env) ~> #declareLocal("...") ~> #callImpl(FuncDef<P, B, Env>, Args)
  rule #callEntry(FuncDef<B:Block, Env:Map>, Args:ValueList) =>
    #setEnv(Env) ~> #declareLocal("...") ~> #callImpl(FuncDef<B, Env>, Args)

  rule #callImpl(FuncDef<(N:Id, Ns:ParamList), B:Block, Env:Map>, (Arg:Value, Args:ValueList)) =>
    local N = Arg ~> #callImpl(FuncDef<Ns, B, Env>, Args)
  rule #callImpl(FuncDef<N:Id, B:Block, Env:Map>, (Arg:Value, Args:ValueList)) =>
    local N = Arg ~> #callImpl(FuncDef<B, Env>, Args)
  rule #callImpl(FuncDef<(N:Id, Ns:ParamList), B:Block, Env:Map>, .ValueList) =>
    local N ~> #callImpl(FuncDef<Ns, B, Env>, .ValueList)
  rule #callImpl(FuncDef<N:Id, B:Block, Env:Map>, .ValueList) =>
    local N ~> #callImpl(FuncDef<B, Env>, .ValueList)
  rule <k> #callImpl(FuncDef<(...):Varargs, B:Block, Env:Map>, Args:ValueList) =>
             #callImpl(FuncDef<B, Env>, .ValueList) ...</k>
       <env>... "..." |-> L:Int ...</env>
       <store>... L |-> (_ => Args) ...</store>
  rule #callImpl(FuncDef<B:Block, Env:Map>, Args:ValueList) => B

  syntax K ::= #setEnv(Map)
  rule <k> #setEnv(M:Map) => . ...</k>
       <env> _ => M:Map </env>

  syntax StackFrame ::= "StackFrame" "<" FrameType "," Map "," K ">"
                     //  StackFrame   <  FrameType  , <env> , <k> >
  syntax FrameType ::= "CallFrame" | "LoopFrame" | "ScopeFrame" | "CatchFrame"
  syntax K ::= #enter(FrameType, K)
  rule <k> #enter(T:FrameType, B) ~> Rest => B </k>
       <env> M </env>
       <fstack> .List => ListItem(StackFrame<T, M, Rest>) ...</fstack>

  syntax FunctionCall ::= #return(FrameType, ExpressionList) [strict(2)]
                        | #return(FrameType) [klabel(#return_nil)]
                        | #returnImpl(FrameType, K)
  rule <k> #return(T:FrameType, E:ValueList) ~> Rest:K => #returnImpl(T, (E:ValueList):K) </k>
  rule <k> #return(T:FrameType) ~> Rest:K => #returnImpl(T, .) </k>

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
  rule #assignList((V:Var, Vs:VarList), .ValueList) => #assign(V, nil) ~> #assignList(Vs, .ValueList)
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
                        | #setImpl(Expression, Expression, Expression) [strict]
  rule #set(T:Value, K:Value, V:Value) => #rawget(T, K) ~> #set(T, K, V)
  rule nil ~> #set(T:Value, K:Value, V:Value) => #metatableGet(T, "__newindex") ~> #setImpl(T, K, V)
  rule F:Value ~> #set(T:Value, K:Value, V:Value) => #rawset(T, K, V) when F =/=K nil
  rule nil ~> #setImpl(T:Value, K:Value, V:Value) => #rawset(T, K, V)
  rule F:FuncPtr ~> #setImpl(T:Value, K:Value, V:Value) => #callEntry(F, (T, K, V, .ValueList))
  rule F:TablePtr ~> #setImpl(T:Value, K:Value, V:Value) => #set(F, K, V)

  syntax FunctionCall ::= #rawset(Expression, Expression, Expression) [strict]
  rule <k> #rawset(Table<T:Int>, N:Value, V:Value) => . ...</k>
       <heap>... T |-> (M:Map => M[N <- V]) ...</heap> when V =/=K nil andBool notBool (N ==K nil orBool isFloat(N))
  rule <k> #rawset(Table<T:Int>, N:Value, nil) => . ...</k>
       <heap>... T |-> (M:Map => M[N <- undef]) ...</heap> when notBool (N ==K nil orBool isFloat(N))
  rule <k> #rawset(Table<T:Int>, N:Float, V:Value) => . ...</k>
       <heap>... T |-> (M:Map => M[N <- V]) ...</heap> when V =/=K nil andBool notBool isNaN(N)
  rule <k> #rawset(Table<T:Int>, N:Float, nil) => . ...</k>
       <heap>... T |-> (M:Map => M[N <- undef]) ...</heap> when notBool isNaN(N)
  rule #rawset(T:TablePtr, nil, V:Value) => #error("table index is nil")
  rule #rawset(T:TablePtr, N:Float, V:Value) => #error("table index is NaN") when isNaN(N)
  rule #rawset(T:Value, N:Value, V:Value) => #error("attempt to index") when notBool isTablePtr(T)

  // table get
  syntax FunctionCall ::= #get(Expression, Expression)
                        | #getImpl(Expression, Expression) [strict]
                        | #getExit(Expression, Expression, Expression) [strict]
  rule #get(T:Expression, K:Expression) => #getImpl(#eval1(T), #eval1(K))
  rule #getImpl(T:Value, K:Value) => #getExit(T, K, #rawget(T, K))
  rule #getExit(T:Value, K:Value, nil) => #metatableGet(T, "__index") ~> #getExit(T, K, nil)
  rule #getExit(T:Value, L:Value, V:Value) => V when V =/=K nil
  rule nil ~> #getExit(T:Value, K:Value, nil) => nil
  rule F:FuncPtr ~> #getExit(T:Value, K:Value, nil) => #eval1(#callEntry(F, (T, K, .ValueList)))
  rule F:TablePtr ~> #getExit(T:Value, K:Value, nil) => #get(F, K)

  syntax FunctionCall ::= #rawget(Expression, Expression) [strict]
  rule <k> #rawget(Table<T:Int>, N:Value) => M:Map[N] ...</k>
       <heap>... T |-> M:Map ...</heap> when N in keys(M)
  rule <k> #rawget(Table<T:Int>, N:Value) => nil ...</k>
       <heap>... T |-> M:Map ...</heap> when notBool(N in keys(M))
  rule #rawget(S:String, N:Value) => nil
  rule #rawget(T:Value, N:Value) => #error("attempt to index") when notBool (isTablePtr(T) orBool isString(T))

  rule E:PrefixExpression [ K:Expression ] => #get(E, K)
  rule (E:PrefixExpression . K:Id):Var => #get(E, Id2String(K))

  // metatable get
  syntax FunctionCall ::= #metatableGet(Value, String)
  rule <k> #metatableGet(Table<L:Int>, K:String) => MT:Map[K] ...</k>
       <metatables>... L |-> Table<M:Int> ...</metatables>
       <heap>... M |-> MT:Map ...</heap> when K in keys(MT)
  rule <k> #metatableGet(Table<L:Int>, K:String) => nil ...</k>
       <metatables>... L |-> Table<M:Int> ...</metatables>
       <heap>... M |-> MT ...</heap> when notBool (K in keys(MT))
  rule <k> #metatableGet(Table<L:Int>, K:String) => nil ...</k>
       <metatables> MTs </metatables> when notBool (L in keys(MTs))
  rule <k> #metatableGet(S:String, K:String) => MT:Map[K] ...</k>
       <metatables>... "" |-> Table<M:Int> ...</metatables>
       <heap>... M |-> MT ...</heap> when K in keys(MT)
  rule <k> #metatableGet(S:String, K:String) => nil ...</k>
       <metatables>... "" |-> Table<M:Int> ...</metatables>
       <heap>... M |-> MT ...</heap> when notBool (K in keys(MT))
  rule <k> #metatableGet(S:String, K:String) => nil ...</k>
       <metatables> MTs </metatables> when notBool ("" in keys(MTs))
  rule #metatableGet(V:Value, K:String) => nil when notBool (isTablePtr(V) orBool isString(V))

  syntax FunctionCall ::= #metatableGetMulti(ValueList, String)
  rule #metatableGetMulti((V:Value, Vs:ValueList), K:String) => #metatableGet(V, K) ~> #metatableGetMulti(Vs, K)
  rule nil ~> #metatableGetMulti(Vs:ValueList, K:String) => #metatableGetMulti(Vs, K)
  rule M:Value ~> #metatableGetMulti(Vs:ValueList, K:String) => M when M =/=K nil
  rule #metatableGetMulti(.ValueList, K:String) => nil



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
  rule #nfor(N:Id, Var:Float, Limit:Float, 0.0, B:Block) => .
  rule #nfor(N:Id, Var:Float, Limit:Float, Step:Float, B:Block) =>
    (Step >=Float 0.0 andBool Var >Float Limit) orBool (Step <Float 0.0 andBool Var <Float Limit) ~>
    #nfor(N, Var, Limit, Step, B) when Step =/=Float 0.0
  rule true ~> #nfor(N:Id, Var:Float, Limit:Float, Step:Float, B:Block) => break
  rule false ~> #nfor(N:Id, Var:Float, Limit:Float, Step:Float, B:Block) =>
    local N = Var ~> B ~> #nfor(N, Var +Float Step, Limit, Step, B)

  rule #nfor(N:Id, Var:Value, Limit:Value, Step:Value, B:Block) =>
    #error("'for' initial value must be a number") when notBool isFloat(Var)
  rule #nfor(N:Id, Var:Float, Limit:Value, Step:Value, B:Block) =>
    #error("'for' limit must be a number") when notBool isFloat(Limit)
  rule #nfor(N:Id, Var:Float, Limit:Float, Step:Value, B:Block) =>
    #error("'for' step must be a number") when notBool isFloat(Step)

  rule for N:Id = X:Expression, Y:Expression do B:Block end => for N = X, Y, 1.0 do B end
  rule for N:Id = X:Expression, Y:Expression, Z:Expression do B:Block end =>
    #enter(LoopFrame, #nfor(N, #tonumber(X), #tonumber(Y), #tonumber(Z), B))

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
  rule for N:IdList in (F:Value, (S:Value, .ValueList)) do B:Block end =>
    #enter(LoopFrame, #ifor(N, F, S, nil, B))
  rule for N:IdList in (F:Value, .ValueList) do B:Block end =>
    #enter(LoopFrame, #ifor(N, F, nil, nil, B))



  // builtin print
  syntax FunctionCall ::= #print(ExpressionList) [strict]
  rule #print(V:Value, Vs:ValueList) => #tostringFunc(V) ~> #print(Vs)
  rule <k> S:String ~> #print(Vs:ValueList) => #print(Vs) ...</k>
       <out>... .List => ListItem(S +String " ") </out> when Vs =/=K .ValueList
  rule <k> S:String ~> #print(.ValueList) => #print(.ValueList) ...</k>
       <out>... .List => ListItem(S +String "\n") </out>
  rule #print(.ValueList) => .

  // builtin tostring
  syntax String ::= #tostring(Expression) [strict, function]
  rule #tostring(S:String) => S
  rule #tostring(N:Float) => Int2String(Float2Int(N)) when N %Float 1.0 ==Float 0.0
  rule #tostring(N:Float) => Float2String(N) when N %Float 1.0 =/=Float 0.0
  rule #tostring(true) => "true"
  rule #tostring(false) => "false"
  rule #tostring(nil) => "nil"
  rule #tostring(Table<L:Int>) => "table: 0x" +String Base2String(L, 16)
  rule #tostring(Func<L:Int>) => "function: 0x" +String Base2String(L, 16)
  rule #tostring(Thread<L:Int>) => "thread: 0x" +String Base2String(L, 16)

  syntax FunctionCall ::= #tostringFunc(Expression) [strict]
                        | #tostringFuncImpl(Expression)
                        | "#tostringFuncExit" "(" ")"
  rule #tostringFunc(V:Value) => #metatableGet(V, "__tostring") ~> #tostringFuncImpl(V)
  rule nil ~> #tostringFuncImpl(V:Value) => #tostring(V)
  rule F:Value ~> #tostringFuncImpl(V:Value) => #eval1(#callEntry(F, V)) ~> #tostringFuncExit() when F =/=K nil
  rule V:Value ~> #tostringFuncExit() => #error("'__tostring' must return a string") when notBool isString(V)
  rule S:String ~> #tostringFuncExit() => S

  // builtin tonumber
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
  syntax String ::= #type(Value) [function]
  rule #type(nil) => "nil"
  rule #type(B:Bool) => "boolean"
  rule #type(N:Float) => "number"
  rule #type(S:String) => "string"
  rule #type(F:FuncPtr) => "function"
  rule #type(T:TablePtr) => "table"
  rule #type(T:ThreadPtr) => "thread"

  syntax FunctionCall ::= #typeFunc(Expression) [strict]
  rule #typeFunc(V:Value) => #type(V)

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

  // builtin getmetatable
  syntax FunctionCall ::= #getmetatable(Expression) [strict]
  rule #getmetatable(T:Value) => #metatableGet(T, "__metatable") ~> #getmetatable(T)
  rule V:Value ~> #getmetatable(T:Value) => V when V =/=K nil
  rule <k> nil ~> #getmetatable(Table<L:Int>) => MT ...</k>
       <metatables>... L |-> MT ...</metatables>
  rule <k> nil ~> #getmetatable(Table<L:Int>) => nil ...</k>
       <metatables> MTs </metatables> when notBool (L in keys(MTs))
  rule <k> nil ~> #getmetatable(S:String) => MT ...</k>
       <metatables>... "" |-> MT ...</metatables>
  rule nil ~> #getmetatable(V:Value) => nil when notBool (isTablePtr(V) orBool isString(V))

  // builtin setmetatable
  syntax FunctionCall ::= #setmetatable(Expression, Expression) [strict]
  rule #setmetatable(T:Value, MT:Value) => #metatableGet(T, "__metatable") ~> #setmetatable(T, MT)
  rule <k> nil ~> #setmetatable(Table<L:Int>, MT:Value) => . ...</k>
       <metatables> MTs => MTs[L <- MT] </metatables> when MT =/=K nil
  rule <k> nil ~> #setmetatable(Table<L:Int>, nil) => . ...</k>
       <metatables> MTs => MTs[L <- undef] </metatables>
  rule <k> nil ~> #setmetatable(S:String, MT:Value) => . ...</k>
       <metatables> MTs => MTs["" <- MT] </metatables>
  rule V:Value ~> #setmetatable(T:Value, MT:Value) => #error("cannot change a protected metatable") when V =/=K nil

  // builtin math.floor
  syntax FunctionCall ::= #mathFloor(Expression) [strict]
  rule #mathFloor(F:Float) => floorFloat(F)

  // builtin math.sqrt
  syntax FunctionCall ::= #mathSqrt(Expression) [strict]
  rule #mathSqrt(F:Float) => sqrtFloat(F)

  // builtin string.byte
  syntax FunctionCall ::= #stringByte(Expression, Expression, Expression) [strict]
                        | #stringByteImpl(String, Float, Float, ValueList) [function]
  rule #stringByte(S:String, I:Float, J:Float) => #stringByteImpl(S, I, J, .ValueList)
  rule #stringByteImpl(S:String, I:Float, J:Float, V:ValueList) =>
    #stringByteImpl(S, I +Float 1.0, J, (IntToFloat(ordChar(substrString(S, Float2Int(I) -Int 1, Float2Int(I)))), V:ValueList))
    when I <=Float J andBool Float2Int(I) <=Int lengthString(S)
  rule #stringByteImpl(S:String, I:Float, J:Float, V:ValueList) => #reverseList(V)
    when notBool (I <=Float J andBool Float2Int(I) <=Int lengthString(S))

  // builtin string.char
  syntax FunctionCall ::= #stringChar(ExpressionList) [strict]
                        | #stringCharImpl(ValueList, String) [function]
  rule #stringChar(V:ValueList) => #stringCharImpl(V, "")
  rule #stringCharImpl((F:Float, Vs:ValueList), S:String) => #stringCharImpl(Vs, S +String chrChar(Float2Int(F)))
  rule #stringCharImpl(.ValueList, S:String) => S



  // predefined error types
  syntax K ::= #arithmeticError(Value) [function]
  rule #arithmeticError(V:Value) => #error("attempt to perform arithmetic on a " +String #type(V) +String " value")

  syntax K ::= #lengthError(Value) [function]
  rule #lengthError(V:Value) => #error("attempt to get length of a " +String #type(V) +String " value")

  syntax K ::= #bitwiseOpError(Value) [function]
  rule #bitwiseOpError(V:Value) => #error("attempt to perform bitwise operation on a " +String #type(V) +String " value")

  syntax K ::= #concatError(Value) [function]
  rule #concatError(V:Value) => #error("attempt to concatenate a " +String #type(V) +String " value")

  syntax K ::= #compareError(Value, Value) [function]
  rule #compareError(A:Value, B:Value) =>
    #error("attempt to compare two " +String #type(A) +String " values") when #type(A) ==K #type(B)
  rule #compareError(A:Value, B:Value) =>
    #error("attempt to compare " +String #type(A) +String " with " +String #type(B)) when #type(A) =/=K #type(B)



  // external process helper
  syntax FunctionCall ::= #callHelper(ValueList)
                        | #callHelperImpl(String, ValueList)
                        | "#callHelperExit" "(" ")"
  rule #callHelper(V:ValueList) => #callHelperImpl("node\x01luahelper.js", V:ValueList)
  rule #callHelperImpl(S:String, (V:String, Vs:ValueList)) =>
    #callHelperImpl(S:String +String "\x01" +String V:String, Vs:ValueList)
  rule #callHelperImpl(S:String, .ValueList) => #system(S) ~> #callHelperExit()
  rule #systemResult(0, S:String, "") ~> #callHelperExit() => S



  // type coercion
  syntax FunctionCall ::= #toboolean(ExpressionList) [strict]
  syntax Bool ::= #tobooleanImpl(Value) [function]
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
  rule #checkCompareError(A:String, B:String) => .
  rule #checkCompareError(A:Value, B:Value) => #compareError(A, B)
    when notBool((isFloat(A) andBool isFloat(B)) orBool (isString(A) andBool isString(B)))



  // power
  syntax FunctionCall ::= #pow(Expression, Expression) [strict]
                        | #powImpl(Expression, Expression) [strict]
  rule A:Expression ^ B:Expression => #pow(#eval1(A), #eval1(B))
  rule #pow(A:Value, B:Value) => #metatableGetMulti(A, B, "__pow") ~> #pow(A, B)
  rule nil ~> #pow(A:Value, B:Value) => #powImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #pow(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #powImpl(A:Float, B:Float) => A ^Float B

  // boolean not
  syntax FunctionCall ::= #not(Expression) [strict]
  rule not E:Expression => #not(#toboolean(E:Expression))
  rule #not(B:Bool) => notBool B

  // length
  syntax FunctionCall ::= #len(Expression) [strict]
                        | #lenImpl(Expression, Expression) [strict]
  rule # E:Expression => #len(#eval1(E))
  rule #len(V:Value) => #metatableGet(V, "__len") ~> #len(V)
  rule nil ~> #len(V:Value) => #lenImpl(V, 1.0)
  rule F:Value ~> #len(V:Value) => #eval1(#callEntry(F, (V, V, .ValueList))) when F =/=K nil

  rule #lenImpl(L:TablePtr, Pos:Float) => #rawget(L, Pos) == nil ~> #lenImpl(L, Pos +Float 1.0)
  rule true ~> #lenImpl(L:TablePtr, Pos:Float) => Pos -Float 2.0
  rule false ~> #lenImpl(L:TablePtr, Pos:Float) => #lenImpl(L:TablePtr, Pos:Float)
  rule #lenImpl(S:String, Pos:Float) => IntToFloat(lengthString(S))
  rule #lenImpl(E:Value, Pos:Float) => #lengthError(E) when notBool(isTablePtr(E) orBool isString(E))

  // unary minus
  syntax FunctionCall ::= #unm(Expression) [strict]
                        | #unmImpl(Expression) [strict]
  rule - E:Expression => #unm(#eval1(E))
  rule #unm(V:Value) => #metatableGet(V, "__unm") ~> #unm(V)
  rule nil ~> #unm(V:Value) => #unmImpl(#arithmeticParam(V))
  rule F:Value ~> #unm(V:Value) => #eval1(#callEntry(F, (V, V, .ValueList))) when F =/=K nil
  rule #unmImpl(E:Float) => --Float E

  // bitwise not
  syntax FunctionCall ::= #bnot(Expression) [strict]
                        | #bnotImpl(Expression) [strict]
  rule ~ E:Expression => #bnot(#eval1(E))
  rule #bnot(V:Value) => #metatableGet(V, "__bnot") ~> #bnot(V)
  rule nil ~> #bnot(V:Value) => #bnotImpl(#bitwiseParam(V))
  rule F:Value ~> #bnot(V:Value) => #eval1(#callEntry(F, (V, V, .ValueList))) when F =/=K nil
  rule #bnotImpl(E:Float) => IntToFloat(~Int Float2Int(E))

  // multiplication
  syntax FunctionCall ::= #mul(Expression, Expression) [strict]
                        | #mulImpl(Expression, Expression) [strict]
  rule A:Expression * B:Expression => #mul(#eval1(A), #eval1(B))
  rule #mul(A:Value, B:Value) => #metatableGetMulti(A, B, "__mul") ~> #mul(A, B)
  rule nil ~> #mul(A:Value, B:Value) => #mulImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #mul(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #mulImpl(A:Float, B:Float) => A *Float B

  // division
  syntax FunctionCall ::= #div(Expression, Expression) [strict]
                        | #divImpl(Expression, Expression) [strict]
  rule A:Expression / B:Expression => #div(#eval1(A), #eval1(B))
  rule #div(A:Value, B:Value) => #metatableGetMulti(A, B, "__div") ~> #div(A, B)
  rule nil ~> #div(A:Value, B:Value) => #divImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #div(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #divImpl(A:Float, B:Float) => A /Float B

  // integer division
  syntax FunctionCall ::= #idiv(Expression, Expression) [strict]
                        | #idivImpl(Expression, Expression) [strict]
  rule A:Expression / / B:Expression => #idiv(#eval1(A), #eval1(B))
  rule #idiv(A:Value, B:Value) => #metatableGetMulti(A, B, "__idiv") ~> #idiv(A, B)
  rule nil ~> #idiv(A:Value, B:Value) => #idivImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #idiv(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #idivImpl(A:Float, B:Float) => floorFloat(A /Float B)

  // integer division with left param as integer constant
  syntax FunctionCall ::= #iidiv(Float, Expression) [strict(2)]
                        | #iidivImpl(Float, Expression) [strict(2)]
  rule A:Float i/ / B:Expression => #iidiv(A, #eval1(B))
  rule #iidiv(A:Float, B:Value) => #metatableGet(B, "__idiv") ~> #iidiv(A, B)
  rule nil ~> #iidiv(A:Float, B:Value) => #iidivImpl(A, #arithmeticParam(B))
  rule F:Value ~> #iidiv(A:Float, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil

  rule #iidivImpl(A:Float, B:Value) => #idiv(A, B) when B =/=K (0.0):Float
  rule #iidivImpl(A:Float, 0.0) => #error("attempt to divide by zero")

  // modulo
  syntax FunctionCall ::= #mod(Expression, Expression) [strict]
                        | #modImpl(Expression, Expression) [strict]
  rule A:Expression % B:Expression => #mod(#eval1(A), #eval1(B))
  rule #mod(A:Value, B:Value) => #metatableGetMulti(A, B, "__mod") ~> #mod(A, B)
  rule nil ~> #mod(A, B) => #modImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #mod(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil

  rule #modImpl(A:Float, B:Float) => A -Float floorFloat(A /Float B) *Float B when B =/=Float 0.0
  rule #modImpl(A:Float, 0.0) => #error("attempt to perform 'n%0'")

  // addition
  syntax FunctionCall ::= #add(Expression, Expression) [strict]
                        | #addImpl(Expression, Expression) [strict]
  rule A:Expression + B:Expression => #add(#eval1(A), #eval1(B))
  rule #add(A:Value, B:Value) => #metatableGetMulti(A, B, "__add") ~> #add(A, B)
  rule nil ~> #add(A:Value, B:Value) => #addImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #add(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #addImpl(A:Float, B:Float) => A +Float B

  // subtraction
  syntax FunctionCall ::= #sub(Expression, Expression) [strict]
                        | #subImpl(Expression, Expression) [strict]
  rule A:Expression - B:Expression => #sub(#eval1(A), #eval1(B))
  rule #sub(A:Value, B:Value) => #metatableGetMulti(A, B, "__sub") ~> #sub(A, B)
  rule nil ~> #sub(A:Value, B:Value) => #subImpl(#arithmeticParam(A), #arithmeticParam(B))
  rule F:Value ~> #sub(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #subImpl(A:Float, B:Float) => A -Float B

  // concatenation
  syntax FunctionCall ::= #concat(Expression, Expression) [strict]
                        | #concatImpl(Expression, Expression) [strict]
  rule A:Expression .. B:Expression => #concat(#eval1(A), #eval1(B))
  rule #concat(A:Value, B:Value) => #metatableGetMulti(A, B, "__concat") ~> #concat(A, B)
  rule nil ~> #concat(A:Value, B:Value) => #concatImpl(#concatParam(A), #concatParam(B))
  rule F:Value ~> #concat(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #concatImpl(A:String, B:String) => A +String B

  // bitwise left shift
  syntax FunctionCall ::= #shl(Expression, Expression) [strict]
                        | #shlImpl(Expression, Expression) [strict]
  rule A:Expression << B:Expression => #shl(#eval1(A), #eval1(B))
  rule #shl(A:Value, B:Value) => #metatableGetMulti(A, B, "__shl") ~> #shl(A, B)
  rule nil ~> #shl(A:Value, B:Value) => #shlImpl(#bitwiseParam(A), #bitwiseParam(B))
  rule F:Value ~> #shl(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #shlImpl(A:Float, B:Float) => IntToFloat(Float2Int(A) <<Int Float2Int(B))    // >

  // bitwise right shift
  syntax FunctionCall ::= #shr(Expression, Expression) [strict]
                        | #shrImpl(Expression, Expression) [strict]
  rule A:Expression >> B:Expression => #shr(#eval1(A), #eval1(B))
  rule #shr(A:Value, B:Value) => #metatableGetMulti(A, B, "__shr") ~> #shr(A, B)
  rule nil ~> #shr(A:Value, B:Value) => #shrImpl(#bitwiseParam(A), #bitwiseParam(B))
  rule F:Value ~> #shr(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #shrImpl(A:Float, B:Float) => IntToFloat(Float2Int(A) >>Int Float2Int(B))

  // bitwise and
  syntax FunctionCall ::= #band(Expression, Expression) [strict]
                        | #bandImpl(Expression, Expression) [strict]
  rule A:Expression & B:Expression => #band(#eval1(A), #eval1(B))
  rule #band(A:Value, B:Value) => #metatableGetMulti(A, B, "__band") ~> #band(A, B)
  rule nil ~> #band(A:Value, B:Value) => #bandImpl(#bitwiseParam(A), #bitwiseParam(B))
  rule F:Value ~> #band(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #bandImpl(A:Float, B:Float) => IntToFloat(Float2Int(A) &Int Float2Int(B))

  // bitwise xor
  syntax FunctionCall ::= #bxor(Expression, Expression) [strict]
                        | #bxorImpl(Expression, Expression) [strict]
  rule A:Expression ~ B:Expression => #bxor(#eval1(A), #eval1(B))
  rule #bxor(A:Value, B:Value) => #metatableGetMulti(A, B, "__bxor") ~> #bxor(A, B)
  rule nil ~> #bxor(A:Value, B:Value) => #bxorImpl(#bitwiseParam(A), #bitwiseParam(B))
  rule F:Value ~> #bxor(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #bxorImpl(A:Float, B:Float) => IntToFloat(Float2Int(A) xorInt Float2Int(B))

  // bitwise or
  syntax FunctionCall ::= #bor(Expression, Expression) [strict]
                        | #borImpl(Expression, Expression) [strict]
  rule A:Expression | B:Expression => #bor(#eval1(A), #eval1(B))
  rule #bor(A:Value, B:Value) => #metatableGetMulti(A, B, "__bor") ~> #bor(A, B)
  rule nil ~> #bor(A:Value, B:Value) => #borImpl(#bitwiseParam(A), #bitwiseParam(B))
  rule F:Value ~> #bor(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #borImpl(A:Float, B:Float) => IntToFloat(Float2Int(A) |Int Float2Int(B))

  // lower than
  syntax FunctionCall ::= #lt(Expression, Expression) [strict]
                        | #ltImpl(Value, Value)
  rule A:Expression < B:Expression => #lt(#eval1(A), #eval1(B))
  rule #lt(A:Value, B:Value) => #metatableGetMulti(A, B, "__lt") ~> #lt(A, B)
  rule nil ~> #lt(A:Value, B:Value) => #checkCompareError(A, B) ~> #ltImpl(A, B)
  rule F:Value ~> #lt(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil

  rule #ltImpl(A:Float, B:Float) => A <Float B    // >
  rule #ltImpl(A:String, B:String) => A <String B    // >

  // greater than
  rule A:Expression > B:Expression => B < A    // >

  // lower than or equal
  syntax FunctionCall ::= #le(Expression, Expression) [strict]
                        | #leTryLt(Value, Value)
                        | #leImpl(Value, Value)
  rule A:Expression <= B:Expression => #le(#eval1(A), #eval1(B))
  rule #le(A:Value, B:Value) => #metatableGetMulti(A, B, "__le") ~> #le(A, B)
  rule nil ~> #le(A:Value, B:Value) => #metatableGetMulti(A, B, "__lt") ~> #leTryLt(A, B)
  rule F:Value ~> #le(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule nil ~> #leTryLt(A:Value, B:Value) => #checkCompareError(A, B) ~> #leImpl(A, B)
  rule F:Value ~> #leTryLt(A:Value, B:Value) => not #lt(B, A) when F =/=K nil

  rule #leImpl(A:Float, B:Float) => A <=Float B
  rule #leImpl(A:String, B:String) => A <=String B

  // greater than or equal
  rule A:Expression >= B:Expression => B <= A

  // not equal
  rule A:Expression ~= B:Expression => not (A == B)

  // equal
  syntax FunctionCall ::= #eq(Expression, Expression) [strict]
                        | #eqImpl(Value, Value)
  rule A:Expression == B:Expression => #eq(#eval1(A), #eval1(B))
  rule #eq(A:Value, B:Value) => #metatableGetMulti(A, B, "__eq") ~> #eq(A, B) when #type(A) ==K #type(B)
  rule #eq(A:Value, B:Value) => #eqImpl(A, B) when #type(A) =/=K #type(B)
  rule nil ~> #eq(A:Value, B:Value) => #eqImpl(A, B)
  rule F:Value ~> #eq(A:Value, B:Value) => #eval1(#callEntry(F, (A, B, .ValueList))) when F =/=K nil
  rule #eqImpl(A:Value, B:Value) => A ==K B

  // boolean and
  syntax K ::= #andThen(Expression)
  rule A:Expression and B:Expression => #eval1(A) ~> #andThen(B)
  rule V:Value ~> #andThen(B:Expression) => B when #tobooleanImpl(V)
  rule V:Value ~> #andThen(B:Expression) => V when notBool #tobooleanImpl(V)

  // boolean or
  syntax K ::= #orThen(Expression)
  rule A:Expression or B:Expression => #eval1(A) ~> #orThen(B)
  rule V:Value ~> #orThen(B:Expression) => V when #tobooleanImpl(V)
  rule V:Value ~> #orThen(B:Expression) => B when notBool #tobooleanImpl(V)
endmodule
