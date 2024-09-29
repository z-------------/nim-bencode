import std/[
  algorithm,
  macros,
]

macro sortedFieldPairsImpl(ty: object; nameIdent, valueIdent, body: untyped) =
  body.expectKind nnkStmtList
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
    let newBody = newStmtList(
      newProc(nameIdent, [bindSym"untyped"], newLit(name.strVal), nnkTemplateDef, nnkPragma.newTree(ident"used")),
      newProc(valueIdent, [bindSym"untyped"], newDotExpr(ty, name), nnkTemplateDef, nnkPragma.newTree(ident"used")),
    )
    for node in body:
      newBody.add node
    result.add newBlockStmt(newBody)

macro sortedFieldPairs*(loop: ForLoopStmt) =
  if loop.len != 4:
    error("wrong number of arguments")
  let
    nameIdent = loop[0]
    valueIdent = loop[1]
    call = loop[2]
    body = loop[3]
  call.expectKind nnkCall
  let tyIdent = call[1]
  result = newCall(bindSym"sortedFieldPairsImpl", tyIdent, nameIdent, valueIdent, body)

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

import ../types

template effectiveName*(fieldName, fieldValue: untyped): untyped =
  when fieldValue.hasCustomPragma(types.name):
    fieldValue.getCustomPragmaVal(types.name)
  else:
    fieldName
