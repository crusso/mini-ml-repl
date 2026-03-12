import Text "mo:core/Text";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Char "mo:core/Char";

actor {
  // ─────────────────────────────────────────────
  // Tokens
  // ─────────────────────────────────────────────
  type Token = {
    #TInt : Int; #TBool : Bool; #TString : Text; #TIdent : Text;
    #TFun; #TLet; #TRec; #TIn; #TIf; #TThen; #TElse;
    #TArrow; #TEq; #TPlus; #TMinus; #TStar; #TSlash;
    #TLt; #TGt; #TLe; #TGe; #TAnd; #TOr;
    #TLParen; #TRParen; #TComma; #TSemicolon; #TEOF;
  };

  // ─────────────────────────────────────────────
  // AST
  // ─────────────────────────────────────────────
  type Lit = { #LInt : Int; #LBool : Bool; #LString : Text };
  type BinOp = { #Add; #Sub; #Mul; #Div; #Eq; #Lt; #Gt; #Le; #Ge; #And; #Or };
  type Expr = {
    #Lit : Lit; #Var : Text; #App : (Expr, Expr); #Lam : (Text, Expr);
    #Let : (Text, Expr, Expr); #LetRec : (Text, Text, Expr, Expr);
    #If : (Expr, Expr, Expr); #BinOp : (BinOp, Expr, Expr);
    #Tuple : [Expr]; #Unit;
  };

  // ─────────────────────────────────────────────
  // Types (HM)
  // ─────────────────────────────────────────────
  type Ty = {
    #TVar : Nat; #TInt; #TBool; #TString; #TUnit;
    #TArrow : (Ty, Ty); #TTuple : [Ty];
  };
  type Scheme = { vars : [Nat]; ty : Ty };
  type Subst = [(Nat, Ty)];
  type TyEnv = [(Text, Scheme)];

  // ─────────────────────────────────────────────
  // Values
  // ─────────────────────────────────────────────
  type Value = {
    #VInt : Int; #VBool : Bool; #VString : Text; #VUnit;
    #VClosure : { param : Text; body : Expr; env : ValEnv };
    #VRecClosure : { fname : Text; param : Text; body : Expr; env : ValEnv };
    #VTuple : [Value]; #VBuiltin : Text;
  };
  type ValEnv = [(Text, Value)];

  // ─────────────────────────────────────────────
  // Result type (avoid deprecated Result module)
  // ─────────────────────────────────────────────
  type Res<T> = { #ok : T; #err : Text };

  // ─────────────────────────────────────────────
  // Mutable State
  // ─────────────────────────────────────────────
  var freshCounter : Nat = 0;
  var tyEnvState : TyEnv = [];
  var valEnvState : ValEnv = [];

  // ─────────────────────────────────────────────
  // Array helpers using List internally
  // ─────────────────────────────────────────────
  func arrFind<T>(arr : [T], pred : T -> Bool) : ?T {
    var i = 0;
    while (i < arr.size()) {
      if (pred(arr[i])) return ?arr[i];
      i += 1;
    };
    null
  };

  func arrMap<A, B>(arr : [A], f : A -> B) : [B] {
    let out = List.empty<B>();
    for (x in arr.vals()) out.add(f(x));
    out.toArray()
  };

  func arrFilter<T>(arr : [T], pred : T -> Bool) : [T] {
    let out = List.empty<T>();
    for (x in arr.vals()) { if (pred(x)) out.add(x) };
    out.toArray()
  };

  func arrConcat<T>(a : [T], b : [T]) : [T] {
    let out = List.empty<T>();
    for (x in a.vals()) out.add(x);
    for (x in b.vals()) out.add(x);
    out.toArray()
  };

  // ─────────────────────────────────────────────
  // Lexer helpers
  // ─────────────────────────────────────────────
  func isDigit(c : Char) : Bool { c >= '0' and c <= '9' };
  func isAlpha(c : Char) : Bool {
    (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_'
  };
  func isAlNum(c : Char) : Bool { isAlpha(c) or isDigit(c) };

  // Use Nat32 codes for special chars to avoid char literal issues
  let dquoteCode : Nat32 = 34; // "
  let bslashCode : Nat32 = 92; // \

  func tokenize(src : Text) : Res<[Token]> {
    let charArr = src.chars().toArray();
    let tokens = List.empty<Token>();
    var i = 0;
    let n = charArr.size();
    while (i < n) {
      let c = charArr[i];
      let cc = c.toNat32();
      if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
        i += 1;
      } else if (c == '(' and i + 1 < n and charArr[i + 1] == '*') {
        i += 2;
        var found = false;
        while (i + 1 < n and not found) {
          if (charArr[i] == '*' and charArr[i + 1] == ')') {
            i += 2; found := true;
          } else { i += 1 };
        };
        if (not found) { i := n };
      } else if (c == '(') { tokens.add(#TLParen); i += 1 }
      else if (c == ')') { tokens.add(#TRParen); i += 1 }
      else if (c == ',') { tokens.add(#TComma); i += 1 }
      else if (c == ';') { tokens.add(#TSemicolon); i += 1 }
      else if (c == '+') { tokens.add(#TPlus); i += 1 }
      else if (c == '*') { tokens.add(#TStar); i += 1 }
      else if (c == '/') { tokens.add(#TSlash); i += 1 }
      else if (c == '-') {
        if (i + 1 < n and charArr[i + 1] == '>') { tokens.add(#TArrow); i += 2 }
        else { tokens.add(#TMinus); i += 1 };
      } else if (c == '<') {
        if (i + 1 < n and charArr[i + 1] == '=') { tokens.add(#TLe); i += 2 }
        else { tokens.add(#TLt); i += 1 };
      } else if (c == '>') {
        if (i + 1 < n and charArr[i + 1] == '=') { tokens.add(#TGe); i += 2 }
        else { tokens.add(#TGt); i += 1 };
      } else if (c == '=') { tokens.add(#TEq); i += 1 }
      else if (c == '&' and i + 1 < n and charArr[i + 1] == '&') { tokens.add(#TAnd); i += 2 }
      else if (c == '|' and i + 1 < n and charArr[i + 1] == '|') { tokens.add(#TOr); i += 2 }
      else if (cc == dquoteCode) {
        i += 1;
        let sb = List.empty<Char>();
        var closed = false;
        while (i < n and not closed) {
          let sc = charArr[i];
          let scc = sc.toNat32();
          if (scc == dquoteCode) { closed := true; i += 1 }
          else if (scc == bslashCode and i + 1 < n) {
            let ec = charArr[i + 1];
            if (ec == 'n') { sb.add('\n') }
            else if (ec == 't') { sb.add('\t') }
            else if (ec.toNat32() == dquoteCode) { sb.add(Char.fromNat32(dquoteCode)) }
            else if (ec.toNat32() == bslashCode) { sb.add(Char.fromNat32(bslashCode)) }
            else { sb.add(ec) };
            i += 2;
          } else { sb.add(sc); i += 1 };
        };
        if (not closed) return #err("Unterminated string literal");
        tokens.add(#TString(Text.fromIter(sb.values())));
      } else if (isDigit(c)) {
        var num : Int = 0;
        while (i < n and isDigit(charArr[i])) {
          let d : Int = (charArr[i].toNat32() - '0'.toNat32()).toNat().toInt();
          num := num * 10 + d;
          i += 1;
        };
        tokens.add(#TInt(num));
      } else if (isAlpha(c)) {
        let sb = List.empty<Char>();
        while (i < n and isAlNum(charArr[i])) { sb.add(charArr[i]); i += 1 };
        let word = Text.fromIter(sb.values());
        let tok : Token = switch (word) {
          case "fun" #TFun; case "let" #TLet; case "rec" #TRec;
          case "in" #TIn; case "if" #TIf; case "then" #TThen;
          case "else" #TElse; case "true" #TBool(true); case "false" #TBool(false);
          case _ #TIdent(word);
        };
        tokens.add(tok);
      } else return #err("Unexpected character: " # Text.fromChar(c));
    };
    tokens.add(#TEOF);
    #ok(tokens.toArray())
  };

  // ─────────────────────────────────────────────
  // Parser
  // ─────────────────────────────────────────────
  type ParseState = { tokens : [Token]; var pos : Nat };

  func peek(ps : ParseState) : Token {
    if (ps.pos < ps.tokens.size()) ps.tokens[ps.pos] else #TEOF
  };
  func advance(ps : ParseState) : Token {
    let t = peek(ps); ps.pos += 1; t
  };
  func expect(ps : ParseState, expected : Token) : Res<()> {
    let t = advance(ps);
    if (tokenEq(t, expected)) #ok(())
    else #err("Expected " # tokenName(expected) # " but got " # tokenName(t))
  };

  func tokenEq(a : Token, b : Token) : Bool {
    switch (a, b) {
      case (#TFun,#TFun) true; case (#TLet,#TLet) true; case (#TRec,#TRec) true;
      case (#TIn,#TIn) true; case (#TIf,#TIf) true; case (#TThen,#TThen) true;
      case (#TElse,#TElse) true; case (#TArrow,#TArrow) true; case (#TEq,#TEq) true;
      case (#TPlus,#TPlus) true; case (#TMinus,#TMinus) true; case (#TStar,#TStar) true;
      case (#TSlash,#TSlash) true; case (#TLt,#TLt) true; case (#TGt,#TGt) true;
      case (#TLe,#TLe) true; case (#TGe,#TGe) true; case (#TAnd,#TAnd) true;
      case (#TOr,#TOr) true; case (#TLParen,#TLParen) true; case (#TRParen,#TRParen) true;
      case (#TComma,#TComma) true; case (#TSemicolon,#TSemicolon) true; case (#TEOF,#TEOF) true;
      case _ false;
    }
  };

  func tokenName(t : Token) : Text {
    switch (t) {
      case (#TInt(n)) "int(" # n.toText() # ")";
      case (#TBool(b)) if (b) "true" else "false";
      case (#TString(s)) s; case (#TIdent(s)) s;
      case (#TFun) "fun"; case (#TLet) "let"; case (#TRec) "rec"; case (#TIn) "in";
      case (#TIf) "if"; case (#TThen) "then"; case (#TElse) "else"; case (#TArrow) "->";
      case (#TEq) "="; case (#TPlus) "+"; case (#TMinus) "-"; case (#TStar) "*";
      case (#TSlash) "/"; case (#TLt) "<"; case (#TGt) ">"; case (#TLe) "<=";
      case (#TGe) ">="; case (#TAnd) "&&"; case (#TOr) "||"; case (#TLParen) "(";
      case (#TRParen) ")"; case (#TComma) ","; case (#TSemicolon) ";"; case (#TEOF) "EOF";
    }
  };

  // Parse a single parameter identifier
  func parseLetRecBody(ps : ParseState, fname : Text) : Res<Expr> {
    // Supports two forms:
    //   let rec f x = <body> [in <cont>]        (parameter before =)
    //   let rec f = fun x -> <body> [in <cont>] (lambda on rhs)
    switch (peek(ps)) {
      case (#TEq) {
        // let rec f = fun x -> body [in cont]
        ignore advance(ps);
        switch (peek(ps)) {
          case (#TFun) {
            ignore advance(ps);
            let param = switch (advance(ps)) {
              case (#TIdent(n)) n;
              case t return #err("Expected parameter after 'fun', got " # tokenName(t));
            };
            switch (expect(ps, #TArrow)) { case (#err(e)) return #err(e); case (#ok _) {} };
            let body = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
            switch (peek(ps)) {
              case (#TIn) {
                ignore advance(ps);
                let cont = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
                #ok(#LetRec(fname, param, body, cont))
              };
              case _ #ok(#LetRec(fname, param, body, #Var(fname)));
            };
          };
          case t return #err("Expected 'fun' after 'let rec " # fname # " =', got " # tokenName(t));
        };
      };
      case _ {
        // let rec f x = body [in cont]
        let param = switch (advance(ps)) {
          case (#TIdent(n)) n;
          case t return #err("Expected parameter after function name, got " # tokenName(t));
        };
        switch (expect(ps, #TEq)) { case (#err(e)) return #err(e); case (#ok _) {} };
        let body = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
        switch (peek(ps)) {
          case (#TIn) {
            ignore advance(ps);
            let cont = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
            #ok(#LetRec(fname, param, body, cont))
          };
          case _ #ok(#LetRec(fname, param, body, #Var(fname)));
        };
      };
    };
  };

  func parseExpr(ps : ParseState) : Res<Expr> {
    switch (peek(ps)) {
      case (#TLet) {
        ignore advance(ps);
        switch (peek(ps)) {
          case (#TRec) {
            ignore advance(ps);
            let fname = switch (advance(ps)) {
              case (#TIdent(n)) n;
              case t return #err("Expected function name after 'let rec', got " # tokenName(t));
            };
            parseLetRecBody(ps, fname)
          };
          case _ {
            let name = switch (advance(ps)) {
              case (#TIdent(n)) n;
              case t return #err("Expected name after 'let', got " # tokenName(t));
            };
            switch (expect(ps, #TEq)) { case (#err(e)) return #err(e); case (#ok _) {} };
            let rhs = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
            switch (peek(ps)) {
              case (#TIn) {
                ignore advance(ps);
                let body = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
                #ok(#Let(name, rhs, body))
              };
              case _ #ok(#Let(name, rhs, #Var(name)));
            };
          };
        };
      };
      case (#TFun) {
        ignore advance(ps);
        let param = switch (advance(ps)) {
          case (#TIdent(n)) n;
          case t return #err("Expected parameter after 'fun', got " # tokenName(t));
        };
        switch (expect(ps, #TArrow)) { case (#err(e)) return #err(e); case (#ok _) {} };
        let body = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
        #ok(#Lam(param, body))
      };
      case (#TIf) {
        ignore advance(ps);
        let cond = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
        switch (expect(ps, #TThen)) { case (#err(e)) return #err(e); case (#ok _) {} };
        let thn = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
        switch (expect(ps, #TElse)) { case (#err(e)) return #err(e); case (#ok _) {} };
        let els = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
        #ok(#If(cond, thn, els))
      };
      case _ parseOrExpr(ps);
    }
  };

  func parseOrExpr(ps : ParseState) : Res<Expr> {
    var lhs = switch (parseAndExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
    loop {
      switch (peek(ps)) {
        case (#TOr) {
          ignore advance(ps);
          let rhs = switch (parseAndExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
          lhs := #BinOp(#Or, lhs, rhs);
        };
        case _ return #ok(lhs);
      };
    };
  };

  func parseAndExpr(ps : ParseState) : Res<Expr> {
    var lhs = switch (parseCmpExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
    loop {
      switch (peek(ps)) {
        case (#TAnd) {
          ignore advance(ps);
          let rhs = switch (parseCmpExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
          lhs := #BinOp(#And, lhs, rhs);
        };
        case _ return #ok(lhs);
      };
    };
  };

  func parseCmpExpr(ps : ParseState) : Res<Expr> {
    var lhs = switch (parseAddExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
    loop {
      let op : ?BinOp = switch (peek(ps)) {
        case (#TEq) ?#Eq; case (#TLt) ?#Lt; case (#TGt) ?#Gt;
        case (#TLe) ?#Le; case (#TGe) ?#Ge; case _ null;
      };
      switch (op) {
        case (?o) {
          ignore advance(ps);
          let rhs = switch (parseAddExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
          lhs := #BinOp(o, lhs, rhs);
        };
        case null return #ok(lhs);
      };
    };
  };

  func parseAddExpr(ps : ParseState) : Res<Expr> {
    var lhs = switch (parseMulExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
    loop {
      let op : ?BinOp = switch (peek(ps)) {
        case (#TPlus) ?#Add; case (#TMinus) ?#Sub; case _ null;
      };
      switch (op) {
        case (?o) {
          ignore advance(ps);
          let rhs = switch (parseMulExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
          lhs := #BinOp(o, lhs, rhs);
        };
        case null return #ok(lhs);
      };
    };
  };

  func parseMulExpr(ps : ParseState) : Res<Expr> {
    var lhs = switch (parseAppExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
    loop {
      let op : ?BinOp = switch (peek(ps)) {
        case (#TStar) ?#Mul; case (#TSlash) ?#Div; case _ null;
      };
      switch (op) {
        case (?o) {
          ignore advance(ps);
          let rhs = switch (parseAppExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
          lhs := #BinOp(o, lhs, rhs);
        };
        case null return #ok(lhs);
      };
    };
  };

  func isAtomStart(t : Token) : Bool {
    switch (t) {
      case (#TInt _) true; case (#TBool _) true; case (#TString _) true;
      case (#TIdent _) true; case (#TLParen) true; case _ false;
    }
  };

  func parseAppExpr(ps : ParseState) : Res<Expr> {
    var func_ = switch (parseAtom(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
    loop {
      if (isAtomStart(peek(ps))) {
        let arg = switch (parseAtom(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
        func_ := #App(func_, arg);
      } else return #ok(func_);
    };
  };

  func parseAtom(ps : ParseState) : Res<Expr> {
    switch (peek(ps)) {
      case (#TInt(n)) { ignore advance(ps); #ok(#Lit(#LInt(n))) };
      case (#TBool(b)) { ignore advance(ps); #ok(#Lit(#LBool(b))) };
      case (#TString(s)) { ignore advance(ps); #ok(#Lit(#LString(s))) };
      case (#TIdent(name)) { ignore advance(ps); #ok(#Var(name)) };
      case (#TLParen) {
        ignore advance(ps);
        switch (peek(ps)) {
          case (#TRParen) { ignore advance(ps); #ok(#Unit) };
          case _ {
            let first = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
            switch (peek(ps)) {
              case (#TComma) {
                let elems = List.empty<Expr>();
                elems.add(first);
                while (tokenEq(peek(ps), #TComma)) {
                  ignore advance(ps);
                  let e = switch (parseExpr(ps)) { case (#err(e)) return #err(e); case (#ok e) e };
                  elems.add(e);
                };
                switch (expect(ps, #TRParen)) { case (#err(e)) return #err(e); case (#ok _) {} };
                #ok(#Tuple(elems.toArray()))
              };
              case (#TRParen) { ignore advance(ps); #ok(first) };
              case t return #err("Expected ')' or ',' but got " # tokenName(t));
            };
          };
        };
      };
      case t return #err("Unexpected token: " # tokenName(t));
    }
  };

  // ─────────────────────────────────────────────
  // Type Utilities
  // ─────────────────────────────────────────────
  func freshVar() : Ty {
    let n = freshCounter;
    freshCounter += 1;
    #TVar(n)
  };

  func applySubst(s : Subst, t : Ty) : Ty {
    switch (t) {
      case (#TVar(n)) {
        switch (arrFind(s, func((k, _)) { k == n })) {
          case (?(_, ty)) applySubst(s, ty);
          case null #TVar(n);
        };
      };
      case (#TArrow(a, b)) #TArrow(applySubst(s, a), applySubst(s, b));
      case (#TTuple(ts)) #TTuple(arrMap(ts, func t_ { applySubst(s, t_) }));
      case other other;
    }
  };

  func applySubstToEnv(s : Subst, env : TyEnv) : TyEnv {
    arrMap(env, func (name, sc) {
      (name, { vars = sc.vars; ty = applySubst(s, sc.ty) })
    })
  };

  func composeSubst(s1 : Subst, s2 : Subst) : Subst {
    let buf = List.empty<(Nat, Ty)>();
    for ((k, v) in s2.vals()) buf.add((k, applySubst(s1, v)));
    for ((k, v) in s1.vals()) {
      switch (arrFind(s2, func((k2, _)) { k2 == k })) {
        case null buf.add((k, v));
        case _ {};
      };
    };
    buf.toArray()
  };

  func occursIn(n : Nat, t : Ty) : Bool {
    switch (t) {
      case (#TVar(m)) m == n;
      case (#TArrow(a, b)) occursIn(n, a) or occursIn(n, b);
      case (#TTuple(ts)) arrFind(ts, func t_ { occursIn(n, t_) }) != null;
      case _ false;
    }
  };

  func unify(t1 : Ty, t2 : Ty) : Res<Subst> {
    switch (t1, t2) {
      case (#TInt, #TInt) #ok([]);
      case (#TBool, #TBool) #ok([]);
      case (#TString, #TString) #ok([]);
      case (#TUnit, #TUnit) #ok([]);
      case (#TVar(n), #TVar(m)) {
        if (n == m) #ok([]) else #ok([(n, #TVar(m))])
      };
      case (#TVar(n), t) {
        if (occursIn(n, t)) #err("Infinite type")
        else #ok([(n, t)])
      };
      case (t, #TVar(n)) {
        if (occursIn(n, t)) #err("Infinite type")
        else #ok([(n, t)])
      };
      case (#TArrow(a1, b1), #TArrow(a2, b2)) {
        let s1 = switch (unify(a1, a2)) { case (#err(e)) return #err(e); case (#ok s) s };
        let s2 = switch (unify(applySubst(s1, b1), applySubst(s1, b2))) {
          case (#err(e)) return #err(e); case (#ok s) s
        };
        #ok(composeSubst(s2, s1))
      };
      case (#TTuple(ts1), #TTuple(ts2)) {
        if (ts1.size() != ts2.size()) {
          return #err("Tuple arity mismatch: expected " # ts1.size().toText() # " got " # ts2.size().toText());
        };
        var s : Subst = [];
        var i = 0;
        while (i < ts1.size()) {
          let si = switch (unify(applySubst(s, ts1[i]), applySubst(s, ts2[i]))) {
            case (#err(e)) return #err(e); case (#ok si) si
          };
          s := composeSubst(si, s);
          i += 1;
        };
        #ok(s)
      };
      case _ #err("Cannot unify " # typeToString(t1) # " with " # typeToString(t2));
    }
  };

  func freeTyVars(t : Ty) : [Nat] {
    let buf = List.empty<Nat>();
    func go(ty : Ty) {
      switch (ty) {
        case (#TVar(n)) buf.add(n);
        case (#TArrow(a, b)) { go(a); go(b) };
        case (#TTuple(ts)) { for (t_ in ts.vals()) go(t_) };
        case _ {};
      };
    };
    go(t);
    let seen = List.empty<Nat>();
    for (n in buf.values()) {
      if (arrFind(seen.toArray(), func m { m == n }) == null) seen.add(n);
    };
    seen.toArray()
  };

  func freeTyVarsInEnv(env : TyEnv) : [Nat] {
    let buf = List.empty<Nat>();
    for ((_, sc) in env.vals()) {
      let ftv = freeTyVars(sc.ty);
      for (n in ftv.vals()) {
        if (arrFind(sc.vars, func m { m == n }) == null) buf.add(n);
      };
    };
    buf.toArray()
  };

  func generalize(env : TyEnv, t : Ty) : Scheme {
    let envFtv = freeTyVarsInEnv(env);
    let tyFtv = freeTyVars(t);
    let genVars = arrFilter(tyFtv, func n {
      arrFind(envFtv, func m { m == n }) == null
    });
    { vars = genVars; ty = t }
  };

  func instantiate(sc : Scheme) : Ty {
    if (sc.vars.size() == 0) return sc.ty;
    let mapping = arrMap(sc.vars, func n { (n, freshVar()) });
    applySubst(mapping, sc.ty)
  };

  // ─────────────────────────────────────────────
  // Type Inference (Algorithm W)
  // ─────────────────────────────────────────────
  func infer(env : TyEnv, expr : Expr) : Res<(Subst, Ty)> {
    switch (expr) {
      case (#Lit(#LInt _)) #ok(([], #TInt));
      case (#Lit(#LBool _)) #ok(([], #TBool));
      case (#Lit(#LString _)) #ok(([], #TString));
      case (#Unit) #ok(([], #TUnit));

      case (#Var(name)) {
        switch (arrFind(env, func (n, _) { n == name })) {
          case (?(_, sc)) #ok(([], instantiate(sc)));
          case null #err("Unbound variable: " # name);
        };
      };

      case (#Lam(param, body)) {
        let tv = freshVar();
        let newEnv = arrConcat([(param, { vars = []; ty = tv })], env);
        let (s1, t1) = switch (infer(newEnv, body)) { case (#err(e)) return #err(e); case (#ok r) r };
        #ok((s1, #TArrow(applySubst(s1, tv), t1)))
      };

      case (#App(fn, arg)) {
        let tv = freshVar();
        let (s1, t1) = switch (infer(env, fn)) { case (#err(e)) return #err(e); case (#ok r) r };
        let (s2, t2) = switch (infer(applySubstToEnv(s1, env), arg)) {
          case (#err(e)) return #err(e); case (#ok r) r
        };
        let s3 = switch (unify(applySubst(s2, t1), #TArrow(t2, tv))) {
          case (#err(e)) return #err("Type error in application: " # e); case (#ok s) s
        };
        #ok((composeSubst(s3, composeSubst(s2, s1)), applySubst(s3, tv)))
      };

      case (#Let(name, rhs, body)) {
        let (s1, t1) = switch (infer(env, rhs)) { case (#err(e)) return #err(e); case (#ok r) r };
        let env1 = applySubstToEnv(s1, env);
        let sc = generalize(env1, t1);
        let newEnv = arrConcat([(name, sc)], env1);
        let (s2, t2) = switch (infer(newEnv, body)) { case (#err(e)) return #err(e); case (#ok r) r };
        #ok((composeSubst(s2, s1), t2))
      };

      case (#LetRec(fname, param, body, cont)) {
        let tv = freshVar();
        let envF = arrConcat([(fname, { vars = []; ty = tv })], env);
        let tvParam = freshVar();
        let envFP = arrConcat([(param, { vars = []; ty = tvParam })], envF);
        let (s1, t1) = switch (infer(envFP, body)) { case (#err(e)) return #err(e); case (#ok r) r };
        let funcType = #TArrow(applySubst(s1, tvParam), t1);
        let s2 = switch (unify(applySubst(s1, tv), funcType)) {
          case (#err(e)) return #err("Recursive type error: " # e); case (#ok s) s
        };
        let sAll = composeSubst(s2, s1);
        let env1 = applySubstToEnv(sAll, env);
        let sc = generalize(env1, applySubst(sAll, funcType));
        let newEnv = arrConcat([(fname, sc)], env1);
        let (s3, _t3) = switch (infer(newEnv, cont)) { case (#err(e)) return #err(e); case (#ok r) r };
        let t3 = _t3;
        #ok((composeSubst(s3, sAll), t3))
      };

      case (#If(cond, thn, els)) {
        let (s1, t1) = switch (infer(env, cond)) { case (#err(e)) return #err(e); case (#ok r) r };
        let s2 = switch (unify(t1, #TBool)) {
          case (#err(e)) return #err("Condition must be bool: " # e); case (#ok s) s
        };
        let env2 = applySubstToEnv(composeSubst(s2, s1), env);
        let (s3, t3) = switch (infer(env2, thn)) { case (#err(e)) return #err(e); case (#ok r) r };
        let (s4, t4) = switch (infer(applySubstToEnv(s3, env2), els)) {
          case (#err(e)) return #err(e); case (#ok r) r
        };
        let s5 = switch (unify(applySubst(s4, t3), t4)) {
          case (#err(e)) return #err("Branch type mismatch: " # e); case (#ok s) s
        };
        let sAll = composeSubst(s5, composeSubst(s4, composeSubst(s3, composeSubst(s2, s1))));
        #ok((sAll, applySubst(s5, t4)))
      };

      case (#BinOp(op, lhs, rhs)) {
        let (s1, t1) = switch (infer(env, lhs)) { case (#err(e)) return #err(e); case (#ok r) r };
        let (s2, t2) = switch (infer(applySubstToEnv(s1, env), rhs)) {
          case (#err(e)) return #err(e); case (#ok r) r
        };
        let sBase = composeSubst(s2, s1);
        switch (op) {
          case (#Add or #Sub or #Mul or #Div) {
            let s3 = switch (unify(applySubst(sBase, t1), #TInt)) {
              case (#err(e)) return #err("Expected int: " # e); case (#ok s) s
            };
            let s4 = switch (unify(applySubst(composeSubst(s3, sBase), t2), #TInt)) {
              case (#err(e)) return #err("Expected int: " # e); case (#ok s) s
            };
            #ok((composeSubst(s4, composeSubst(s3, sBase)), #TInt))
          };
          case (#Lt or #Gt or #Le or #Ge) {
            let s3 = switch (unify(applySubst(sBase, t1), #TInt)) {
              case (#err(e)) return #err("Expected int for comparison: " # e); case (#ok s) s
            };
            let s4 = switch (unify(applySubst(composeSubst(s3, sBase), t2), #TInt)) {
              case (#err(e)) return #err("Expected int for comparison: " # e); case (#ok s) s
            };
            #ok((composeSubst(s4, composeSubst(s3, sBase)), #TBool))
          };
          case (#Eq) {
            let tv = freshVar();
            let s3 = switch (unify(applySubst(sBase, t1), tv)) {
              case (#err(e)) return #err(e); case (#ok s) s
            };
            let s4 = switch (unify(applySubst(composeSubst(s3, sBase), t2), applySubst(s3, tv))) {
              case (#err(e)) return #err("Equality type mismatch: " # e); case (#ok s) s
            };
            #ok((composeSubst(s4, composeSubst(s3, sBase)), #TBool))
          };
          case (#And or #Or) {
            let s3 = switch (unify(applySubst(sBase, t1), #TBool)) {
              case (#err(e)) return #err("Expected bool: " # e); case (#ok s) s
            };
            let s4 = switch (unify(applySubst(composeSubst(s3, sBase), t2), #TBool)) {
              case (#err(e)) return #err("Expected bool: " # e); case (#ok s) s
            };
            #ok((composeSubst(s4, composeSubst(s3, sBase)), #TBool))
          };
        }
      };

      case (#Tuple(elems)) {
        var s : Subst = [];
        let types = List.empty<Ty>();
        var curEnv = env;
        for (e in elems.vals()) {
          let (si, ti) = switch (infer(curEnv, e)) {
            case (#err(err)) return #err(err); case (#ok r) r
          };
          s := composeSubst(si, s);
          types.add(ti);
          curEnv := applySubstToEnv(si, curEnv);
        };
        let finalTypes = arrMap(types.toArray(), func t_ { applySubst(s, t_) });
        #ok((s, #TTuple(finalTypes)))
      };
    }
  };

  // ─────────────────────────────────────────────
  // Type Printing
  // ─────────────────────────────────────────────
  func varName(n : Nat) : Text {
    let letters = ["a", "b", "c", "d", "e", "f", "g", "h"];
    if (n < letters.size()) letters[n] else "t" # n.toText()
  };

  func textJoin(parts : [Text], sep : Text) : Text {
    var result = "";
    var first = true;
    for (p in parts.vals()) {
      if (first) { result := p; first := false }
      else result := result # sep # p;
    };
    result
  };

  func typeToString(t : Ty) : Text { typeToStringPrec(t, 0) };

  func typeToStringPrec(t : Ty, prec : Nat) : Text {
    switch (t) {
      case (#TVar(n)) "'" # varName(n);
      case (#TInt) "int";
      case (#TBool) "bool";
      case (#TString) "string";
      case (#TUnit) "unit";
      case (#TArrow(a, b)) {
        let s = typeToStringPrec(a, 1) # " -> " # typeToStringPrec(b, 0);
        if (prec >= 1) "(" # s # ")" else s
      };
      case (#TTuple(ts)) {
        if (ts.size() == 0) "unit"
        else {
          let parts = arrMap(ts, func t_ { typeToStringPrec(t_, 2) });
          let inner = textJoin(parts, " * ");
          if (prec >= 2) "(" # inner # ")" else inner
        }
      };
    }
  };

  // ─────────────────────────────────────────────
  // Evaluator
  // ─────────────────────────────────────────────
  func applyBuiltin(name : Text, arg : Value) : Res<Value> {
    switch (name) {
      case "not" {
        switch (arg) {
          case (#VBool(b)) #ok(#VBool(not b));
          case _ #err("not: expected bool");
        }
      };
      case "fst" {
        switch (arg) {
          case (#VTuple(vs)) {
            if (vs.size() >= 1) #ok(vs[0]) else #err("fst: empty tuple")
          };
          case _ #err("fst: expected tuple");
        }
      };
      case "snd" {
        switch (arg) {
          case (#VTuple(vs)) {
            if (vs.size() >= 2) #ok(vs[1]) else #err("snd: tuple too small")
          };
          case _ #err("snd: expected tuple");
        }
      };
      case _ #err("Unknown builtin: " # name);
    }
  };

  func evalExpr(env : ValEnv, expr : Expr) : Res<Value> {
    switch (expr) {
      case (#Lit(#LInt(n))) #ok(#VInt(n));
      case (#Lit(#LBool(b))) #ok(#VBool(b));
      case (#Lit(#LString(s))) #ok(#VString(s));
      case (#Unit) #ok(#VUnit);

      case (#Var(name)) {
        switch (arrFind(env, func (n, _) { n == name })) {
          case (?(_, v)) #ok(v);
          case null #err("Unbound variable: " # name);
        };
      };

      case (#Lam(param, body)) #ok(#VClosure({ param; body; env }));

      case (#App(fn, arg)) {
        let fv = switch (evalExpr(env, fn)) { case (#err(e)) return #err(e); case (#ok v) v };
        let av = switch (evalExpr(env, arg)) { case (#err(e)) return #err(e); case (#ok v) v };
        switch (fv) {
          case (#VClosure({ param; body; env = closEnv })) {
            let newEnv = arrConcat([(param, av)], closEnv);
            evalExpr(newEnv, body)
          };
          case (#VRecClosure({ fname; param; body; env = closEnv })) {
            let newEnv = arrConcat([(param, av), (fname, fv)], closEnv);
            evalExpr(newEnv, body)
          };
          case (#VBuiltin(bname)) applyBuiltin(bname, av);
          case _ #err("Cannot apply non-function value");
        }
      };

      case (#Let(name, rhs, body)) {
        let rv = switch (evalExpr(env, rhs)) { case (#err(e)) return #err(e); case (#ok v) v };
        let newEnv = arrConcat([(name, rv)], env);
        evalExpr(newEnv, body)
      };

      case (#LetRec(fname, param, body, cont)) {
        let recClosure = #VRecClosure({ fname; param; body; env });
        let finalEnv = arrConcat([(fname, recClosure)], env);
        evalExpr(finalEnv, cont)
      };

      case (#If(cond, thn, els)) {
        let cv = switch (evalExpr(env, cond)) { case (#err(e)) return #err(e); case (#ok v) v };
        switch (cv) {
          case (#VBool(true)) evalExpr(env, thn);
          case (#VBool(false)) evalExpr(env, els);
          case _ #err("Condition is not a boolean");
        }
      };

      case (#BinOp(op, lhs, rhs)) {
        let lv = switch (evalExpr(env, lhs)) { case (#err(e)) return #err(e); case (#ok v) v };
        let rv = switch (evalExpr(env, rhs)) { case (#err(e)) return #err(e); case (#ok v) v };
        switch (op, lv, rv) {
          case (#Add, #VInt(a), #VInt(b)) #ok(#VInt(a + b));
          case (#Sub, #VInt(a), #VInt(b)) #ok(#VInt(a - b));
          case (#Mul, #VInt(a), #VInt(b)) #ok(#VInt(a * b));
          case (#Div, #VInt(a), #VInt(b)) {
            if (b == 0) #err("Division by zero") else #ok(#VInt(a / b))
          };
          case (#Lt, #VInt(a), #VInt(b)) #ok(#VBool(a < b));
          case (#Gt, #VInt(a), #VInt(b)) #ok(#VBool(a > b));
          case (#Le, #VInt(a), #VInt(b)) #ok(#VBool(a <= b));
          case (#Ge, #VInt(a), #VInt(b)) #ok(#VBool(a >= b));
          case (#Eq, #VInt(a), #VInt(b)) #ok(#VBool(a == b));
          case (#Eq, #VBool(a), #VBool(b)) #ok(#VBool(a == b));
          case (#Eq, #VString(a), #VString(b)) #ok(#VBool(a == b));
          case (#Eq, #VUnit, #VUnit) #ok(#VBool(true));
          case (#And, #VBool(a), #VBool(b)) #ok(#VBool(a and b));
          case (#Or, #VBool(a), #VBool(b)) #ok(#VBool(a or b));
          case _ #err("Type error in binary operation");
        }
      };

      case (#Tuple(elems)) {
        let vals = List.empty<Value>();
        for (e in elems.vals()) {
          switch (evalExpr(env, e)) {
            case (#err(err)) return #err(err);
            case (#ok v) vals.add(v);
          };
        };
        #ok(#VTuple(vals.toArray()))
      };
    }
  };

  func valueToString(v : Value) : Text {
    switch (v) {
      case (#VInt(n)) n.toText();
      case (#VBool(b)) if (b) "true" else "false";
      case (#VString(s)) {
        let q = Text.fromChar(Char.fromNat32(dquoteCode));
        q # s # q
      };
      case (#VUnit) "()";
      case (#VClosure _) "<fun>";
      case (#VRecClosure _) "<fun>";
      case (#VBuiltin _) "<fun>";
      case (#VTuple(vs)) {
        let parts = arrMap(vs, valueToString);
        "(" # textJoin(parts, ", ") # ")"
      };
    }
  };

  // ─────────────────────────────────────────────
  // Prelude
  // ─────────────────────────────────────────────
  let preludeTyEnv : TyEnv = [
    ("not", { vars = []; ty = #TArrow(#TBool, #TBool) }),
    ("fst", { vars = [0, 1]; ty = #TArrow(#TTuple([#TVar(0), #TVar(1)]), #TVar(0)) }),
    ("snd", { vars = [0, 1]; ty = #TArrow(#TTuple([#TVar(0), #TVar(1)]), #TVar(1)) }),
  ];

  let preludeValEnv : ValEnv = [
    ("not", #VBuiltin("not")),
    ("fst", #VBuiltin("fst")),
    ("snd", #VBuiltin("snd")),
  ];

  // ─────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────
  public func evaluate(input : Text) : async { #ok : { value : Text; typeStr : Text }; #err : Text } {
    let tokens = switch (tokenize(input)) {
      case (#err(e)) return #err("Lex error: " # e);
      case (#ok ts) ts;
    };
    let ps : ParseState = { tokens; var pos = 0 };
    let expr = switch (parseExpr(ps)) {
      case (#err(e)) return #err("Parse error: " # e);
      case (#ok e) e;
    };
    switch (peek(ps)) {
      case (#TEOF or #TSemicolon) {};
      case (t) return #err("Unexpected token after expression: " # tokenName(t));
    };

    let fullTyEnv = arrConcat(tyEnvState, preludeTyEnv);
    let (subst, ty) = switch (infer(fullTyEnv, expr)) {
      case (#err(e)) return #err("Type error: " # e);
      case (#ok r) r;
    };
    let finalTy = applySubst(subst, ty);

    let fullValEnv = arrConcat(valEnvState, preludeValEnv);
    let value = switch (evalExpr(fullValEnv, expr)) {
      case (#err(e)) return #err("Runtime error: " # e);
      case (#ok v) v;
    };

    switch (expr) {
      case (#Let(name, _, _) or #LetRec(name, _, _, _)) {
        let sc = generalize(arrConcat(tyEnvState, preludeTyEnv), finalTy);
        tyEnvState := arrConcat([(name, sc)], tyEnvState);
        valEnvState := arrConcat([(name, value)], valEnvState);
      };
      case _ {};
    };

    #ok({ value = valueToString(value); typeStr = typeToString(finalTy) })
  };

  public func reset() : async () {
    tyEnvState := [];
    valEnvState := [];
    freshCounter := 0;
  };

  public func getEnv() : async [{ name : Text; typeStr : Text; valueStr : Text }] {
    arrMap(
      tyEnvState,
      func (name, sc) {
        let valStr = switch (arrFind(valEnvState, func (n, _) { n == name })) {
          case (?(_, v)) valueToString(v);
          case null "?";
        };
        { name; typeStr = typeToString(sc.ty); valueStr = valStr }
      }
    )
  };
};
