import { spawnSync } from "node:child_process";
import { availableParallelism, tmpdir } from "node:os";
import {
  constants, copyFileSync, existsSync, mkdirSync, mkdtempSync,
  readFileSync, rmSync, writeFileSync,
} from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";

const [repoRoot, packageDir, dependency, pname, ...args] = process.argv.slice(2);
let requestedVersion = "latest";
let versionSupplied = false;
let verifyBuild = false;
for (const arg of args) {
  if (arg === "--build") {
    verifyBuild = true;
  } else if (!arg.startsWith("-") && !versionSupplied) {
    requestedVersion = arg;
    versionSupplied = true;
  } else {
    throw new Error(`Usage: bump.sh [version] [--build]. Unexpected argument: ${arg}`);
  }
}

function run(command, commandArgs, capture = false, env = {}) {
  const result = spawnSync(command, commandArgs, {
    cwd: packageDir,
    env: { ...process.env, ...env },
    encoding: "utf8",
    stdio: capture ? ["ignore", "pipe", "inherit"] : "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} failed (${result.signal ?? result.status})`);
  }
  return capture ? result.stdout.trim() : undefined;
}

function readJson(file) {
  return JSON.parse(readFileSync(join(packageDir, file), "utf8"));
}

function writeJson(file, value) {
  writeFileSync(join(packageDir, file), `${JSON.stringify(value, null, 2)}\n`);
}

const nixFile = join(packageDir, "default.nix");
const originalNix = readFileSync(nixFile, "utf8");
const hashPattern = /npmDepsHash = "(sha256-[A-Za-z0-9+/]{43}=)";/;
const oldHash = originalNix.match(hashPattern)?.[1];
if (!oldHash || !/version = "[^"]*";/.test(originalNix)) {
  throw new Error("Could not find version and npmDepsHash in default.nix");
}

run("npm", [
  "install", "--package-lock-only", "--ignore-scripts", "--save-exact",
  "--no-audit", "--no-fund", `${dependency}@${requestedVersion}`,
]);

const pkg = readJson("package.json");
const lock = readJson("package-lock.json");
const pinnedVersion = lock.packages[`node_modules/${dependency}`]?.version;
if (!pinnedVersion || !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(pinnedVersion)) {
  throw new Error(`Invalid resolved version for ${dependency}: ${pinnedVersion}`);
}
pkg.version = pinnedVersion;
pkg.dependencies[dependency] = pinnedVersion;
lock.version = pinnedVersion;
lock.packages[""].version = pinnedVersion;
lock.packages[""].dependencies[dependency] = pinnedVersion;
writeJson("package.json", pkg);
writeJson("package-lock.json", lock);

const jobs = String(Math.max(1, Math.ceil(availableParallelism() / 2)));
const buildExpr = `let
  flake = builtins.getFlake "git+file://${repoRoot}?dir=hosts/mercury";
  pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  src = builtins.path { path = ${JSON.stringify(packageDir)}; name = "${pname}-src"; };
  in pkgs.callPackage src {}`;

function segmentedPath(root, hash) {
  return join(root, hash.slice(0, 2), hash.slice(2, 4), hash.slice(4));
}

function reuseDependencies(previousCache, cacheDir) {
  const missing = { ...lock, packages: { "": lock.packages[""] } };
  let reused = 0;
  // Delegate unusual lockfiles to the pinned prefetcher rather than approximating its parser.
  const urls = Object.values(lock.packages).map(entry => entry.resolved).filter(Boolean);
  const registryOnly = lock.lockfileVersion === 3 && new Set(urls).size === urls.length
    && Object.entries(lock.packages).every(([name, entry]) =>
      name === "" || (entry.resolved?.startsWith("https://")
        && /^sha(1|256|384|512)-[A-Za-z0-9+/]+=*$/.test(entry.integrity)));
  if (!registryOnly) {
    console.log("Prefetching the full lockfile (requires the pinned prefetcher's parser).");
    return { missing: lock, reused: 0 };
  }
  for (const [name, entry] of Object.entries(lock.packages)) {
    if (name === "") continue;
    const key = `make-fetch-happen:request-cache:${entry.resolved}`;
    const indexHash = createHash("sha256").update(key).digest("hex");
    const indexPath = segmentedPath("_cacache/index-v5", indexHash);
    const [algorithm, digest] = entry.integrity.split("-");
    const contentPath = segmentedPath(
      `_cacache/content-v2/${algorithm}`, Buffer.from(digest, "base64").toString("hex"),
    );
    if (existsSync(join(previousCache, indexPath))
        && existsSync(join(previousCache, contentPath))) {
      const index = readFileSync(join(previousCache, indexPath), "utf8");
      const cachedEntry = JSON.parse(index.slice(index.indexOf("\t") + 1));
      if (cachedEntry.key === key && cachedEntry.integrity === entry.integrity) {
        for (const path of [indexPath, contentPath]) {
          const target = join(cacheDir, path);
          mkdirSync(dirname(target), { recursive: true });
          copyFileSync(join(previousCache, path), target, constants.COPYFILE_FICLONE);
        }
        reused += 1;
        continue;
      }
    }
    missing.packages[name] = entry;
  }
  return { missing, reused };
}

const previousCache = run("nix", [
  "eval", "--impure", "--raw", "--expr", `(${buildExpr}).npmDeps.outPath`,
], true);
const currentLock = readFileSync(join(packageDir, "package-lock.json"));
const cachedLock = join(previousCache, "package-lock.json");
let newHash = oldHash;
if (!existsSync(cachedLock) || !readFileSync(cachedLock).equals(currentLock)
    || oldHash === "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=") {
  const cacheDir = mkdtempSync(join(tmpdir(), "bump-npm-deps-"));
  try {
    const { missing, reused } = reuseDependencies(previousCache, cacheDir);
    const downloads = Object.keys(missing.packages).length - 1;
    console.log(`Reusing ${reused} cached dependencies; prefetching ${downloads} lockfile entries.`);
    if (downloads > 0) {
      const partialLock = join(cacheDir, "missing-package-lock.json");
      writeFileSync(partialLock, `${JSON.stringify(missing, null, 2)}\n`);
      run("prefetch-npm-deps", [partialLock, cacheDir], false, {
        NIX_BUILD_CORES: jobs,
        NPM_FETCHER_VERSION: "1",
      });
      rmSync(partialLock);
    } else {
      mkdirSync(join(cacheDir, "_cacache/content-v2"), { recursive: true });
      mkdirSync(join(cacheDir, "_cacache/index-v5"), { recursive: true });
    }
    writeFileSync(join(cacheDir, "package-lock.json"), currentLock);
    newHash = run("nix", ["hash", "path", "--sri", cacheDir], true);
    if (!/^sha256-[A-Za-z0-9+/]{43}=$/.test(newHash)) {
      throw new Error(`Invalid npm dependency hash: ${newHash}`);
    }
    run("nix", [
      "store", "add-path", "--name", `${pname}-${pinnedVersion}-npm-deps`, cacheDir,
    ], true);
  } finally {
    rmSync(cacheDir, { recursive: true, force: true });
  }
}

writeFileSync(nixFile, originalNix
  .replace(/version = "[^"]*";/, `version = "${pinnedVersion}";`)
  .replace(hashPattern, `npmDepsHash = "${newHash}";`));

if (verifyBuild) {
  run("nix", [
    "build", "--max-jobs", jobs, "--cores", jobs,
    "--impure", "--no-link", "--expr", buildExpr,
  ]);
}

console.log(`Pinned ${dependency} ${pinnedVersion}`);
console.log(`npmDepsHash = ${newHash}`);
if (!verifyBuild) console.log("To verify the package build, rerun with --build.");
