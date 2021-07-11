local metadep = {}
function metadep.inject_num_assign(name, num)
  inject_statement(aster.Assign{{aster.Id{name}}, {aster.Number{num}}})
end
return metadep
