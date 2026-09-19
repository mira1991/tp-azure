plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

config {
  call_module_type = "local"
}

# Not part of the recommended preset; the rest of that preset is left at its
# defaults on purpose.
rule "terraform_naming_convention" {
  enabled = true
}
