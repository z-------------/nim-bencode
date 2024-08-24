import std/[
  algorithm,
  macros,
]

proc replaceIdents(body, nameIdent, valueIdent, ty, name: NimNode) =
  nameIdent.expectKind nnkIdent
  valueIdent.expectKind nnkIdent
  ty.expectKind nnkSym
  name.expectKind {nnkSym, nnkIdent}

  for i in 0 ..< body.len:
    case body[i].kind
    of nnkIdent:
      if body[i].eqIdent(nameIdent):
        body[i] = newLit(name.strVal)
      elif body[i].eqIdent(valueIdent):
        body[i] = newDotExpr(ty, name)
    else:
      replaceIdents(body[i], nameIdent, valueIdent, ty, name)

macro sortedFieldPairs*(ty: object; nameIdent, valueIdent, body: untyped) =
  if nameIdent.eqIdent(valueIdent):
    error("names must be different", valueIdent)
  result = newStmtList()
  let objectTy = ty.getTypeImpl
  objectTy.expectKind nnkObjectTy
  let recList = objectTy[2]
  recList.expectKind nnkRecList
  var names = newSeq[NimNode]()
  for son in recList:
    case son.kind
    of nnkIdentDefs:
      names.add son[0]
    of nnkRecCase:
      error("object variants are not supported", son)
    else:
      error("unsupported node kind", son)
  names = names.sortedByIt(it.strVal)
  for name in names:
    let bodyCopy = body.copy
    replaceIdents(bodyCopy, nameIdent, valueIdent, ty, name)
    result.add bodyCopy

proc removeDeprecatedImpl(body: NimNode) =
  case body.kind
  of nnkConstSection:
    for son in body:
      son.expectKind nnkConstDef
      if son[0].kind == nnkPragmaExpr:
        let pragma = son[0][1]
        for i in countdown(pragma.len - 1, 0):
          if pragma[i].kind == nnkExprColonExpr and pragma[i][0].eqIdent("deprecated"):
            pragma.del(i)
  else:
    for son in body:
      removeDeprecatedImpl(son)

macro removeDeprecated*(body: untyped): untyped =
  when NimMajor < 2:
    result = body.copy
    removeDeprecatedImpl(result)
  else:
    result = body
