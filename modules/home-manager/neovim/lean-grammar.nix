{ tree-sitter, fetchFromGitHub }:
tree-sitter.buildGrammar {
  language = "lean";
  version = "0.2.0";
  src = fetchFromGitHub {
    owner = "Julian";
    repo = "tree-sitter-lean";
    rev = "259a2daf7a699cc047221f1e043e4d045fcd6be2";
    hash = "sha256-6g9DRLer/GZbGnv0qk8MEMGHJ84PHH/7ty4bbfNFvWw=";
  };
}
