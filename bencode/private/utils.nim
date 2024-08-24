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
    son.expectKind nnkIdentDefs
    names.add son[0]
  names = names.sortedByIt(it.strVal)
  for name in names:
    let bodyCopy = body.copy
    replaceIdents(bodyCopy, nameIdent, valueIdent, ty, name)
    result.add bodyCopy
