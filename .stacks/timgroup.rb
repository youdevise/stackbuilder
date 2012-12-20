stack "infra" do
  loadbalancer "lb"
end

stack "ref" do
  virtualservice "refapp"
end

env "dev" do
  stack "infra"
  stack "ref"
end
