function adapter = get(id)
%GET Return one adapter by id.
adapter = leotherm.adapter.registry('get', id);
end
