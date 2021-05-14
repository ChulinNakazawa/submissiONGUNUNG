# template

CHINA   = ...
SCHOOL  = ...
DEFAULT = ...

FactorOracle = (s) ->
  @oracle = new Array(s.length+1)
  pi = new Array(s.length+1)
  @oracle[0] = {}
  pi[0] = -1
  for c, i in s
    @oracle[i][c] = i+1
    k = pi[i]
    while k >= 0 and c not of @oracle[k]
      @oracle[k][c] = i+1
      k = pi[k]
    pi[i+1] = (if k == -1 then 0 else @oracle[k][c])
    @oracle[i+1] = {}
  @

FactorOracle::find = (s) ->
  k = 0
  for c in s
    k = @oracle[k][c]
    unless k?
  