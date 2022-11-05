Skip to content
Search or jump to…
Pull requests
Issues
Marketplace
Explore
 
@zakwarlord7 
Your account has been flagged.
Because of that, your profile is hidden from the public. If you believe this is a mistake, contact support to have your account status reviewed.
zakwarlord7
/
pomxml-dep-update
Public
forked from book000/pomxml-dep-update
Code
Pull requests
Actions
Projects
Wiki
Security
Insights
Settings
Comparing changes
Choose two branches to see what’s changed or to start a new pull request. If you need to, you can also .
    
 4 commits
 11 files changed
 1 contributor
Commits on Dec 17, 2021
fix: composite -> javascript

@book000
book000 committed on Dec 17, 2021
 
fix: action error

@book000
book000 committed on Dec 17, 2021
 
fix: compile action error

@book000
book000 committed on Dec 17, 2021
 
fix: readme version

@book000
book000 committed on Dec 17, 2021
 
Showing  with 239 additions and 43 deletions.
 50  
.github/workflows/compile.yml
@@ -0,0 +1,50 @@
name: Compile

on:
  push:
    branches:
      - master

jobs:
  update:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout 🛎
        uses: actions/checkout@master

      - name: Setup node env 🏗
        uses: actions/setup-node@v2.5.0
        with:
          node-version: 16

      - name: Get yarn cache directory path 🛠
        id: yarn-cache-dir-path
        run: echo "::set-output name=dir::$(yarn cache dir)"

      - name: Cache node_modules 📦
        uses: actions/cache@v2.1.7
        id: yarn-cache # use this to check for `cache-hit` (`steps.yarn-cache.outputs.cache-hit != 'true'`)
        with:
          path: ${{ steps.yarn-cache-dir-path.outputs.dir }}
          key: ${{ runner.os }}-yarn-${{ hashFiles('**/yarn.lock') }}
          restore-keys: |
            ${{ runner.os }}-yarn-
      - name: Install dependencies 👨🏻‍💻
        run: yarn

      - name: Compile
        run: yarn compile

      - name: Set git config
        run: |
          git config --global user.name "GitHub Action"
          git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
      - name: Create commit & push
        if: ${{ steps.is-modified.outputs.modified == '0' }}
        run: |
          git status | grep modified && git add -A && git commit -v -m "chore: Compile by GitHub Actions" && git push -v || true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
 1  
.gitignore
@@ -1,4 +1,3 @@
dist
node_modules
dist.tgz
config/*
  2  
README.md
@@ -15,7 +15,7 @@ This action may cause destructive changes to the existing file (`pom.xml`).

```yml
- name: pom.xml Dependencies Updater
  uses: book000/pomxml-dep-update@v1.0.0
  uses: book000/pomxml-dep-update@v1.0.1
  with:
    pom-path: pom.xml
    ignore-packages: com.tomacheese.abc,com.tomacheese.def
  14  
action.yml
@@ -12,15 +12,5 @@ inputs:
    required: false
    default: ''
runs:
  using: composite

  steps:
    - name: Install dependencies
      run: |
        yarn
      shell: bash

    - name: Compile & Run
      run: |
        yarn build --target ${{ inputs.target }} --ignore-packages ${{ inputs.ignore-packages }}
      shell: bash
  using: 'node16'
  main: 'dist/main.js'
 2  
dist/main.d.ts
@@ -0,0 +1,2 @@
export {};
//# sourceMappingURL=main.d.ts.map
 1  
dist/main.d.ts.map
@@ -0,0 +1 @@
{"version":3,"file":"main.d.ts","sourceRoot":"","sources":["../src/main.ts"],"names":[],"mappings":""}
 168  
dist/main.js
@@ -0,0 +1,168 @@
import core from '@actions/core';
import axios from 'axios';
import { XMLBuilder, XMLParser } from 'fast-xml-parser';
import fs from 'fs';
import xmlFormat from 'xml-formatter';
const MvnCentralRepository = {
    id: 'mvncentral',
    url: 'https://repo1.maven.org/maven2/',
};
async function parsePom(content) {
    const parser = new XMLParser();
    const pomXml = parser.parse(content);
    const repositories = pomXml.project.repositories.repository;
    const dependencies = pomXml.project.dependencies.dependency;
    return {
        repositories,
        dependencies,
    };
}
async function existsUrl(url) {
    console.log('[existsUrl]', 'url:', url);
    try {
        const response = await axios.get(url);
        console.log('[existsUrl]', 'response:', response.status);
        return response.status === 200;
    }
    catch (error) {
        return false;
    }
}
async function findAsync(array, predicate) {
    for (const t of array) {
        if (await predicate(t)) {
            return t;
        }
    }
    return undefined;
}
function getMavenMetadataXmlUrl(repository, dependency) {
    return (repository.url +
        (dependency.groupId.replace(/\./g, '/') +
            '/' +
            dependency.artifactId +
            '/maven-metadata.xml').replace(/\/\//g, '/'));
}
async function getDependencyRepo(repository, dependency) {
    const depRepo = await findAsync([...repository, MvnCentralRepository], async (repository) => {
        const url = getMavenMetadataXmlUrl(repository, dependency);
        const bool = await existsUrl(url);
        console.log('[getDependencyRepo]', url, bool);
        return bool;
    });
    if (depRepo) {
        return depRepo;
    }
    return null;
}
class MavenMetadata {
    groupId;
    artifactId;
    latestVersion;
    versions;
    constructor(groupId, artifactId, latestVersion, versions) {
        this.groupId = groupId;
        this.artifactId = artifactId;
        this.latestVersion = latestVersion;
        this.versions = versions;
        this.groupId = groupId;
        this.artifactId = artifactId;
        this.latestVersion = latestVersion;
        this.versions = versions;
    }
}
async function parseMavenMetadata(repository, dependency) {
    const url = getMavenMetadataXmlUrl(repository, dependency);
    console.log('[parseMavenMetadata]', 'maven metadata url:', url);
    const content = await axios.get(url);
    const parser = new XMLParser({
        parseTagValue: false,
        parseAttributeValue: false,
    });
    const metadata = parser.parse(content.data);
    return new MavenMetadata(metadata.metadata.groupId, metadata.metadata.artifactId, metadata.metadata.versioning.latest !== undefined
        ? metadata.metadata.versioning.latest
        : metadata.metadata.versioning.release !== undefined
            ? metadata.metadata.versioning.release
            : null, metadata.metadata.versioning.versions.version);
}
async function main(pomPath, ignorePackages) {
    const content = fs.readFileSync(pomPath, 'utf-8');
    const pom = await parsePom(content);
    console.log(pom.repositories);
    console.log(pom.dependencies);
    for (const dependency of pom.dependencies) {
        console.log('[main]', 'Dependency:', JSON.stringify(dependency));
        if (ignorePackages
            .split(',')
            .includes(dependency.groupId + '.' + dependency.artifactId)) {
            console.log('[main]', 'This package is ignored.');
            continue;
        }
        const repository = await getDependencyRepo(pom.repositories, dependency);
        if (!repository) {
            console.warn('[main]', 'Dependency repo:', 'Not found');
            continue;
        }
        console.log('[main]', 'Dependency repo:', JSON.stringify(repository));
        const metadata = await parseMavenMetadata(repository, dependency);
        console.log('[main]', 'Dependency metadata:', JSON.stringify(metadata));
        if (metadata.latestVersion === null) {
            console.warn('[main]', 'Dependency latest version:', 'Not found');
            continue;
        }
        console.log('[main]', 'Dependency latest version:', metadata.latestVersion);
        if (metadata.latestVersion === dependency.version) {
            console.log('[main]', 'Dependency latest version:', 'Latest version');
            continue;
        }
        console.log('[main]', 'Dependency latest version:', 'New version found');
        const replaceDep = pom.dependencies.find((d) => d === dependency);
        if (!replaceDep) {
            continue;
        }
        replaceDep.version = metadata.latestVersion;
        pom.dependencies.splice(pom.dependencies.findIndex((d) => d === dependency), 1, replaceDep);
    }
    const parser = new XMLParser({
        preserveOrder: false,
        trimValues: true,
        ignoreAttributes: false,
        attributesGroupName: false,
        allowBooleanAttributes: true,
        parseTagValue: false,
        parseAttributeValue: false,
        removeNSPrefix: false,
        unpairedTags: ['?xml'],
        commentPropName: '#comment',
    });
    const pomXml = parser.parse(content);
    pomXml.project.repositories = pom.repositories;
    pomXml.project.dependencies = pom.dependencies;
    const xml = new XMLBuilder({
        preserveOrder: false,
        ignoreAttributes: false,
        attributesGroupName: false,
        format: true,
        indentBy: '    ',
        unpairedTags: ['?xml'],
        commentPropName: '#comment',
    })
        .build(pomXml)
        .replace('<?xml version="1.0" encoding="UTF-8"></?xml>', '<?xml version="1.0" encoding="UTF-8"?>')
        .replace(/<\/repositories>[\n ]*<repositories>/g, '</repository><repository>')
        .replace(/<\/dependencies>[\n ]*<dependencies>/g, '</dependency><dependency>')
        .replace('<repositories>', '<repositories><repository>')
        .replace('<dependencies>', '</repositories><dependencies><dependency>')
        .replace('</project>', '</dependencies></project>');
    fs.writeFileSync(pomPath, xmlFormat(xml, {
        collapseContent: true,
    }), 'utf8');
}
;
(async () => {
    const pomPath = core.getInput('pom-path');
    const ignorePackages = core.getInput('ignore-packages');
    main(pomPath, ignorePackages);
})();
//# sourceMappingURL=main.js.map
 1  
dist/main.js.map
@@ -0,0 +1 @@
{"version":3,"file":"main.js","sourceRoot":"","sources":["../src/main.ts"],"names":[],"mappings":"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"}
 1  
dist/tsconfig.tsbuildinfo
@@ -0,0 +1 @@
{"program":{"fileNames":["../node_modules/typescript/lib/lib.es5.d.ts","../node_modules/typescript/lib/lib.es2015.d.ts","../node_modules/typescript/lib/lib.es2016.d.ts","../node_modules/typescript/lib/lib.es2017.d.ts","../node_modules/typescript/lib/lib.es2018.d.ts","../node_modules/typescript/lib/lib.es2019.d.ts","../node_modules/typescript/lib/lib.es2020.d.ts","../node_modules/typescript/lib/lib.es2021.d.ts","../node_modules/typescript/lib/lib.esnext.d.ts","../node_modules/typescript/lib/lib.dom.d.ts","../node_modules/typescript/lib/lib.es2015.core.d.ts","../node_modules/typescript/lib/lib.es2015.collection.d.ts","../node_modules/typescript/lib/lib.es2015.generator.d.ts","../node_modules/typescript/lib/lib.es2015.iterable.d.ts","../node_modules/typescript/lib/lib.es2015.promise.d.ts","../node_modules/typescript/lib/lib.es2015.proxy.d.ts","../node_modules/typescript/lib/lib.es2015.reflect.d.ts","../node_modules/typescript/lib/lib.es2015.symbol.d.ts","../node_modules/typescript/lib/lib.es2015.symbol.wellknown.d.ts","../node_modules/typescript/lib/lib.es2016.array.include.d.ts","../node_modules/typescript/lib/lib.es2017.object.d.ts","../node_modules/typescript/lib/lib.es2017.sharedmemory.d.ts","../node_modules/typescript/lib/lib.es2017.string.d.ts","../node_modules/typescript/lib/lib.es2017.intl.d.ts","../node_modules/typescript/lib/lib.es2017.typedarrays.d.ts","../node_modules/typescript/lib/lib.es2018.asyncgenerator.d.ts","../node_modules/typescript/lib/lib.es2018.asynciterable.d.ts","../node_modules/typescript/lib/lib.es2018.intl.d.ts","../node_modules/typescript/lib/lib.es2018.promise.d.ts","../node_modules/typescript/lib/lib.es2018.regexp.d.ts","../node_modules/typescript/lib/lib.es2019.array.d.ts","../node_modules/typescript/lib/lib.es2019.object.d.ts","../node_modules/typescript/lib/lib.es2019.string.d.ts","../node_modules/typescript/lib/lib.es2019.symbol.d.ts","../node_modules/typescript/lib/lib.es2020.bigint.d.ts","../node_modules/typescript/lib/lib.es2020.promise.d.ts","../node_modules/typescript/lib/lib.es2020.sharedmemory.d.ts","../node_modules/typescript/lib/lib.es2020.string.d.ts","../node_modules/typescript/lib/lib.es2020.symbol.wellknown.d.ts","../node_modules/typescript/lib/lib.es2020.intl.d.ts","../node_modules/typescript/lib/lib.es2021.promise.d.ts","../node_modules/typescript/lib/lib.es2021.string.d.ts","../node_modules/typescript/lib/lib.es2021.weakref.d.ts","../node_modules/typescript/lib/lib.es2021.intl.d.ts","../node_modules/typescript/lib/lib.esnext.intl.d.ts","../node_modules/@actions/core/lib/core.d.ts","../node_modules/axios/index.d.ts","../node_modules/fast-xml-parser/src/fxp.d.ts","../node_modules/xml-formatter/index.d.ts","../src/main.ts","../node_modules/@types/config/index.d.ts","../node_modules/@types/json-schema/index.d.ts","../node_modules/@types/json5/index.d.ts","../node_modules/@types/node/assert.d.ts","../node_modules/@types/node/assert/strict.d.ts","../node_modules/@types/node/globals.d.ts","../node_modules/@types/node/async_hooks.d.ts","../node_modules/@types/node/buffer.d.ts","../node_modules/@types/node/child_process.d.ts","../node_modules/@types/node/cluster.d.ts","../node_modules/@types/node/console.d.ts","../node_modules/@types/node/constants.d.ts","../node_modules/@types/node/crypto.d.ts","../node_modules/@types/node/dgram.d.ts","../node_modules/@types/node/diagnostics_channel.d.ts","../node_modules/@types/node/dns.d.ts","../node_modules/@types/node/dns/promises.d.ts","../node_modules/@types/node/domain.d.ts","../node_modules/@types/node/events.d.ts","../node_modules/@types/node/fs.d.ts","../node_modules/@types/node/fs/promises.d.ts","../node_modules/@types/node/http.d.ts","../node_modules/@types/node/http2.d.ts","../node_modules/@types/node/https.d.ts","../node_modules/@types/node/inspector.d.ts","../node_modules/@types/node/module.d.ts","../node_modules/@types/node/net.d.ts","../node_modules/@types/node/os.d.ts","../node_modules/@types/node/path.d.ts","../node_modules/@types/node/perf_hooks.d.ts","../node_modules/@types/node/process.d.ts","../node_modules/@types/node/punycode.d.ts","../node_modules/@types/node/querystring.d.ts","../node_modules/@types/node/readline.d.ts","../node_modules/@types/node/repl.d.ts","../node_modules/@types/node/stream.d.ts","../node_modules/@types/node/stream/promises.d.ts","../node_modules/@types/node/stream/consumers.d.ts","../node_modules/@types/node/stream/web.d.ts","../node_modules/@types/node/string_decoder.d.ts","../node_modules/@types/node/timers.d.ts","../node_modules/@types/node/timers/promises.d.ts","../node_modules/@types/node/tls.d.ts","../node_modules/@types/node/trace_events.d.ts","../node_modules/@types/node/tty.d.ts","../node_modules/@types/node/url.d.ts","../node_modules/@types/node/util.d.ts","../node_modules/@types/node/v8.d.ts","../node_modules/@types/node/vm.d.ts","../node_modules/@types/node/wasi.d.ts","../node_modules/@types/node/worker_threads.d.ts","../node_modules/@types/node/zlib.d.ts","../node_modules/@types/node/globals.global.d.ts","../node_modules/@types/node/index.d.ts","../node_modules/@types/libmime/index.d.ts","../node_modules/@types/quoted-printable/index.d.ts","../node_modules/@types/strip-bom/index.d.ts","../node_modules/@types/strip-json-comments/index.d.ts","../node_modules/@types/utf8/index.d.ts","../node_modules/@types/yargs-parser/index.d.ts","../node_modules/@types/yargs/index.d.ts"],"fileInfos":[{"version":"89f78430e422a0f06d13019d60d5a45b37ec2d28e67eb647f73b1b0d19a46b72","affectsGlobalScope":true},"dc47c4fa66b9b9890cf076304de2a9c5201e94b740cffdf09f87296d877d71f6","7a387c58583dfca701b6c85e0adaf43fb17d590fb16d5b2dc0a2fbd89f35c467","8a12173c586e95f4433e0c6dc446bc88346be73ffe9ca6eec7aa63c8f3dca7f9","5f4e733ced4e129482ae2186aae29fde948ab7182844c3a5a51dd346182c7b06","e6b724280c694a9f588847f754198fb96c43d805f065c3a5b28bbc9594541c84","e21c071ca3e1b4a815d5f04a7475adcaeea5d64367e840dd0154096d705c3940","746d62152361558ea6d6115cf0da4dd10ede041d14882ede3568bce5dc4b4f1f","2cc028cd0bdb35b1b5eb723d84666a255933fffbea607f72cbd0c7c7b4bee144",{"version":"abba1071bfd89e55e88a054b0c851ea3e8a494c340d0f3fab19eb18f6afb0c9e","affectsGlobalScope":true},{"version":"d8996609230d17e90484a2dd58f22668f9a05a3bfe00bfb1d6271171e54a31fb","affectsGlobalScope":true},{"version":"43fb1d932e4966a39a41b464a12a81899d9ae5f2c829063f5571b6b87e6d2f9c","affectsGlobalScope":true},{"version":"cdccba9a388c2ee3fd6ad4018c640a471a6c060e96f1232062223063b0a5ac6a","affectsGlobalScope":true},{"version":"4378fc8122ec9d1a685b01eb66c46f62aba6b239ca7228bb6483bcf8259ee493","affectsGlobalScope":true},{"version":"0d5f52b3174bee6edb81260ebcd792692c32c81fd55499d69531496f3f2b25e7","affectsGlobalScope":true},{"version":"810627a82ac06fb5166da5ada4159c4ec11978dfbb0805fe804c86406dab8357","affectsGlobalScope":true},{"version":"62d80405c46c3f4c527ee657ae9d43fda65a0bf582292429aea1e69144a522a6","affectsGlobalScope":true},{"version":"3013574108c36fd3aaca79764002b3717da09725a36a6fc02eac386593110f93","affectsGlobalScope":true},{"version":"75ec0bdd727d887f1b79ed6619412ea72ba3c81d92d0787ccb64bab18d261f14","affectsGlobalScope":true},{"version":"3be5a1453daa63e031d266bf342f3943603873d890ab8b9ada95e22389389006","affectsGlobalScope":true},{"version":"17bb1fc99591b00515502d264fa55dc8370c45c5298f4a5c2083557dccba5a2a","affectsGlobalScope":true},{"version":"7ce9f0bde3307ca1f944119f6365f2d776d281a393b576a18a2f2893a2d75c98","affectsGlobalScope":true},{"version":"6a6b173e739a6a99629a8594bfb294cc7329bfb7b227f12e1f7c11bc163b8577","affectsGlobalScope":true},{"version":"12a310447c5d23c7d0d5ca2af606e3bd08afda69100166730ab92c62999ebb9d","affectsGlobalScope":true},{"version":"b0124885ef82641903d232172577f2ceb5d3e60aed4da1153bab4221e1f6dd4e","affectsGlobalScope":true},{"version":"0eb85d6c590b0d577919a79e0084fa1744c1beba6fd0d4e951432fa1ede5510a","affectsGlobalScope":true},{"version":"da233fc1c8a377ba9e0bed690a73c290d843c2c3d23a7bd7ec5cd3d7d73ba1e0","affectsGlobalScope":true},{"version":"d154ea5bb7f7f9001ed9153e876b2d5b8f5c2bb9ec02b3ae0d239ec769f1f2ae","affectsGlobalScope":true},{"version":"bb2d3fb05a1d2ffbca947cc7cbc95d23e1d053d6595391bd325deb265a18d36c","affectsGlobalScope":true},{"version":"c80df75850fea5caa2afe43b9949338ce4e2de086f91713e9af1a06f973872b8","affectsGlobalScope":true},{"version":"9d57b2b5d15838ed094aa9ff1299eecef40b190722eb619bac4616657a05f951","affectsGlobalScope":true},{"version":"6c51b5dd26a2c31dbf37f00cfc32b2aa6a92e19c995aefb5b97a3a64f1ac99de","affectsGlobalScope":true},{"version":"6e7997ef61de3132e4d4b2250e75343f487903ddf5370e7ce33cf1b9db9a63ed","affectsGlobalScope":true},{"version":"2ad234885a4240522efccd77de6c7d99eecf9b4de0914adb9a35c0c22433f993","affectsGlobalScope":true},{"version":"1b3fe904465430e030c93239a348f05e1be80640d91f2f004c3512c2c2c89f34","affectsGlobalScope":true},{"version":"3787b83e297de7c315d55d4a7c546ae28e5f6c0a361b7a1dcec1f1f50a54ef11","affectsGlobalScope":true},{"version":"e7e8e1d368290e9295ef18ca23f405cf40d5456fa9f20db6373a61ca45f75f40","affectsGlobalScope":true},{"version":"faf0221ae0465363c842ce6aa8a0cbda5d9296940a8e26c86e04cc4081eea21e","affectsGlobalScope":true},{"version":"06393d13ea207a1bfe08ec8d7be562549c5e2da8983f2ee074e00002629d1871","affectsGlobalScope":true},{"version":"d071129cba6a5f2700be09c86c07ad2791ab67d4e5ed1eb301d6746c62745ea4","affectsGlobalScope":true},{"version":"6c55633c733c8378db65ac3da7a767c3cf2cf3057f0565a9124a16a3a2019e87","affectsGlobalScope":true},{"version":"fb4416144c1bf0323ccbc9afb0ab289c07312214e8820ad17d709498c865a3fe","affectsGlobalScope":true},{"version":"5b0ca94ec819d68d33da516306c15297acec88efeb0ae9e2b39f71dbd9685ef7","affectsGlobalScope":true},{"version":"e8c9f4e445a489991ca1a4232667de3ac36b07ba75ea335971fbeacf2d26fe67","affectsGlobalScope":true},{"version":"10bbdc1981b8d9310ee75bfac28ee0477bb2353e8529da8cff7cb26c409cb5e8","affectsGlobalScope":true},"b67d387d04e5592bf87aac3eb795926bdaf9dd5c4951150aad9b9db620958b40","644c59289eb29590d65062c5b64dda9ef2797ce120071265a9099436f0d41a16","04091b27f8da99d7279d4974f8dc09a015dfb99d423f5163d0effb82ed375c21","f5e46714d9f9bc844cbc243bc21ab502ce9a0af87af8ac9e7520ec50fb9948d4","4dcf22f454026876eeba4958d7e014318901216334acf304803f9b28ba2e3ec4","db99364aec499a1ab2be97a49c7f65c7fdfa04c6af003595a24085089d5580ea","0359682c54e487c4cab2b53b2b4d35cc8dea4d9914bc6abcdb5701f8b8e745a4","96d14f21b7652903852eef49379d04dbda28c16ed36468f8c9fa08f7c14c9538","0d5a2ee1fdfa82740e0103389b9efd6bfe145a20018a2da3c02b89666181f4d9","a69c09dbea52352f479d3e7ac949fde3d17b195abe90b045d619f747b38d6d1a",{"version":"92d63add669d18ebc349efbacd88966d6f2ccdddfb1b880b2db98ae3aa7bf7c4","affectsGlobalScope":true},"ccc94049a9841fe47abe5baef6be9a38fc6228807974ae675fb15dc22531b4be",{"version":"9acfe4d1ff027015151ce81d60797b04b52bffe97ad8310bb0ec2e8fd61e1303","affectsGlobalScope":true},"95843d5cfafced8f3f8a5ce57d2335f0bcd361b9483587d12a25e4bd403b8216","afc6e96061af46bcff47246158caee7e056f5288783f2d83d6858cd25be1c565",{"version":"34f5bcac12b36d70304b73de5f5aab3bb91bd9919f984be80579ebcad03a624e","affectsGlobalScope":true},"82408ed3e959ddc60d3e9904481b5a8dc16469928257af22a3f7d1a3bc7fd8c4","2f520601649a893e6a49a8851ebfcf4be8ce090dc1281c2a08a871cb04e8251f","f50c975ab7b50e25a69e3d8a3773894125b44e9698924105f23b812bf7488baf","2b8c764f856a1dd0a9a2bf23e5efddbff157de8138b0754010be561ae5fcaa90","76650408392bf49a8fbf3e2b6b302712a92d76af77b06e2da1cc8077359c4409","0af3121e68297b2247dd331c0d24dba599e50736a7517a5622d5591aae4a3122","6972fca26f6e9bd56197568d4379f99071a90766e06b4fcb5920a0130a9202be",{"version":"4a2628e95962c8ab756121faa3ac2ed348112ff7a87b5c286dd2cc3326546b4c","affectsGlobalScope":true},"80793b2277f31baa199234daed806fff0fb11491d1ebd3357e520c3558063f00","a049a59a02009fc023684fcfaf0ac526fe36c35dcc5d2b7d620c1750ba11b083","b9b963043551b034abd9e7c6d859f7a81d99479fde938d983114d167d0644a78","b287b810b5035d5685f1df6e1e418f1ca452a3ed4f59fd5cc081dbf2045f0d9b","4b9a003b5c556c96784132945bb41c655ea11273b1917f5c8d0c154dd5fd20dd","a458dc78104cc80048ac24fdc02fe6dce254838094c2f25641b3f954d9721241",{"version":"e8b18c6385ff784228a6f369694fcf1a6b475355ba89090a88de13587a9391d5","affectsGlobalScope":true},"902cd98bf46e95caf4118a0733fb801e9e90eec3edaed6abdad77124afec9ca2","abc1c425b2ad6720433f40f1877abfa4223f0f3dd486c9c28c492179ca183cb6","cd4854d38f4eb5592afd98ab95ca17389a7dfe38013d9079e802d739bdbcc939","94eed4cc2f5f658d5e229ff1ccd38860bddf4233e347bf78edd2154dee1f2b99",{"version":"bd1a08e30569b0fb2f0b21035eb9b039871f68faa9b98accf847e9c878c5e0a9","affectsGlobalScope":true},"9f1069b9e2c051737b1f9b4f1baf50e4a63385a6a89c32235549ae87fc3d5492","ee18f2da7a037c6ceeb112a084e485aead9ea166980bf433474559eac1b46553","29c2706fa0cc49a2bd90c83234da33d08bb9554ecec675e91c1f85087f5a5324","0acbf26bf958f9e80c1ffa587b74749d2697b75b484062d36e103c137c562bc3","d7838022c7dab596357a9604b9c6adffe37dc34085ce0779c958ce9545bd7139","1b952304137851e45bc009785de89ada562d9376177c97e37702e39e60c2f1ff",{"version":"806ef4cac3b3d9fa4a48d849c8e084d7c72fcd7b16d76e06049a9ed742ff79c0","affectsGlobalScope":true},"a7971f9fb2a32ec7788ec6cda9d7a33c02023dfe9a62db2030ad1359649d8050","c33a6ea7147af60d8e98f1ac127047f4b0d4e2ce28b8f08ff3de07ca7cc00637",{"version":"b42b47e17b8ece2424ae8039feb944c2e3ba4b262986aebd582e51efbdca93dc","affectsGlobalScope":true},"664d8f2d59164f2e08c543981453893bc7e003e4dfd29651ce09db13e9457980","2408611d9b4146e35d1dbd1f443ccd8e187c74614a54b80300728277529dbf11","998a3de5237518c0b3ac00a11b3b4417affb008aa20aedee52f3fdae3cb86151","ad41008ffe077206e1811fc873f4d9005b5fd7f6ab52bb6118fef600815a5cb4","d88ecca73348e7c337541c4b8b60a50aca5e87384f6b8a422fc6603c637e4c21","badae0df9a8016ac36994b0a0e7b82ba6aaa3528e175a8c3cb161e4683eec03e","c3db860bcaaaeb3bbc23f353bbda1f8ab82756c8d5e973bebb3953cb09ea68f2","235a53595bd20b0b0eeb1a29cb2887c67c48375e92f03749b2488fbd46d0b1a0","bc09393cd4cd13f69cf1366d4236fbae5359bb550f0de4e15767e9a91d63dfb1","9c266243b01545e11d2733a55ad02b4c00ecdbda99c561cd1674f96e89cdc958","c71155c05fc76ff948a4759abc1cb9feec036509f500174bc18dad4c7827a60c",{"version":"ab9b9a36e5284fd8d3bf2f7d5fcbc60052f25f27e4d20954782099282c60d23e","affectsGlobalScope":true},"1cdb8f094b969dcc183745dc88404e2d8fcf2a858c6e7cc2441011476573238e","a366e1d03dad03428882527a649c36b20dcd0db765b5c55010bc794adc8d8373","702914ea34d7f5716ba3a7df9cbd0dff30567253a7c0b1c61d1d8b296d5acbbb","4006c872e38a2c4e09c593bc0cdd32b7b4f5c4843910bea0def631c483fff6c5","ab6aa3a65d473871ee093e3b7b71ed0f9c69e07d1d4295f45c9efd91a771241d","ceffc958ebea94978cde2ad88e75fcdf3f89556ea4eafdc03fc7e2aece9bae77","f7e133b20ee2669b6c0e5d7f0cd510868c57cd64b283e68c7f598e30ce9d76d2","e8b8083042a5ae1536d815455fabd3873a8731a760b139723d7fc452bc9a954f"],"options":{"declaration":true,"declarationMap":true,"esModuleInterop":true,"experimentalDecorators":true,"newLine":1,"noFallthroughCasesInSwitch":true,"noImplicitAny":true,"noImplicitReturns":true,"noUnusedLocals":true,"noUnusedParameters":true,"outDir":"./","removeComments":true,"sourceMap":true,"strict":true,"target":99},"fileIdsList":[[97],[97,104],[54,97],[57,97],[58,63,97],[59,69,70,77,86,96,97],[59,60,69,77,97],[61,97],[62,63,70,78,97],[63,86,93,97],[64,66,69,77,97],[65,97],[66,67,97],[68,69,97],[69,97],[69,70,71,86,96,97],[69,70,71,86,97],[72,77,86,96,97],[69,70,72,73,77,86,93,96,97],[72,74,86,93,96,97],[54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103],[69,75,97],[76,96,97],[66,69,77,86,97],[78,97],[79,97],[57,80,97],[81,95,97,101],[82,97],[83,97],[69,84,97],[84,85,97,99],[69,86,87,88,97],[86,88,97],[86,87,97],[89,97],[90,97],[69,91,92,97],[91,92,97],[63,77,93,97],[94,97],[77,95,97],[58,72,83,96,97],[63,97],[86,97,98],[97,99],[97,100],[58,63,69,71,80,86,96,97,99,101],[86,97,102],[97,110],[46,47,48,49,70,97]],"referencedMap":[[46,1],[51,1],[52,1],[53,1],[105,2],[54,3],[55,3],[57,4],[58,5],[59,6],[60,7],[61,8],[62,9],[63,10],[64,11],[65,12],[66,13],[67,13],[68,14],[69,15],[70,16],[71,17],[56,1],[103,1],[72,18],[73,19],[74,20],[104,21],[75,22],[76,23],[77,24],[78,25],[79,26],[80,27],[81,28],[82,29],[83,30],[84,31],[85,32],[86,33],[88,34],[87,35],[89,36],[90,37],[91,38],[92,39],[93,40],[94,41],[95,42],[96,43],[97,44],[98,45],[99,46],[100,47],[101,48],[102,49],[106,1],[107,1],[108,1],[109,1],[110,1],[111,50],[47,1],[48,1],[10,1],[12,1],[11,1],[2,1],[13,1],[14,1],[15,1],[16,1],[17,1],[18,1],[19,1],[20,1],[3,1],[4,1],[24,1],[21,1],[22,1],[23,1],[25,1],[26,1],[27,1],[5,1],[28,1],[29,1],[30,1],[31,1],[6,1],[32,1],[33,1],[34,1],[35,1],[7,1],[40,1],[36,1],[37,1],[38,1],[39,1],[8,1],[44,1],[41,1],[42,1],[43,1],[1,1],[9,1],[45,1],[49,1],[50,51]],"exportedModulesMap":[[46,1],[51,1],[52,1],[53,1],[105,2],[54,3],[55,3],[57,4],[58,5],[59,6],[60,7],[61,8],[62,9],[63,10],[64,11],[65,12],[66,13],[67,13],[68,14],[69,15],[70,16],[71,17],[56,1],[103,1],[72,18],[73,19],[74,20],[104,21],[75,22],[76,23],[77,24],[78,25],[79,26],[80,27],[81,28],[82,29],[83,30],[84,31],[85,32],[86,33],[88,34],[87,35],[89,36],[90,37],[91,38],[92,39],[93,40],[94,41],[95,42],[96,43],[97,44],[98,45],[99,46],[100,47],[101,48],[102,49],[106,1],[107,1],[108,1],[109,1],[110,1],[111,50],[47,1],[48,1],[10,1],[12,1],[11,1],[2,1],[13,1],[14,1],[15,1],[16,1],[17,1],[18,1],[19,1],[20,1],[3,1],[4,1],[24,1],[21,1],[22,1],[23,1],[25,1],[26,1],[27,1],[5,1],[28,1],[29,1],[30,1],[31,1],[6,1],[32,1],[33,1],[34,1],[35,1],[7,1],[40,1],[36,1],[37,1],[38,1],[39,1],[8,1],[44,1],[41,1],[42,1],[43,1],[1,1],[9,1],[45,1],[49,1],[50,51]],"semanticDiagnosticsPerFile":[46,51,52,53,105,54,55,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,56,103,72,73,74,104,75,76,77,78,79,80,81,82,83,84,85,86,88,87,89,90,91,92,93,94,95,96,97,98,99,100,101,102,106,107,108,109,110,111,47,48,10,12,11,2,13,14,15,16,17,18,19,20,3,4,24,21,22,23,25,26,27,5,28,29,30,31,6,32,33,34,35,7,40,36,37,38,39,8,44,41,42,43,1,9,45,49,50]},"version":"4.5.4"}
  7  
package.json
@@ -1,6 +1,6 @@
{
  "name": "pomxml-dep-update",
  "version": "1.0.0",
  "version": "1.0.1",
  "description": "If there is a newer version of the dependency in pom.xml, rewrite it to the latest version.",
  "main": "dist/main.js",
  "repository": "git@github.com:book000/pomxml-dep-update.git",
@@ -21,12 +21,12 @@
    "fix:prettier": "prettier --write src"
  },
  "devDependencies": {
    "@actions/core": "^1.6.0",
    "@types/config": "^0.0.40",
    "@types/libmime": "^5.0.0",
    "@types/node": "^16.11.11",
    "@types/quoted-printable": "^1.0.0",
    "@types/utf8": "^3.0.0",
    "@types/yargs": "^17.0.7",
    "@typescript-eslint/eslint-plugin": "^5.4.0",
    "@typescript-eslint/parser": "^5.4.0",
    "axios": "^0.24.0",
@@ -46,7 +46,6 @@
    "typescript": "^4.5.2",
    "webpack-node-externals": "^3.0.0",
    "xml-formatter": "^2.5.1",
    "yargs": "^17.3.0",
    "yarn-run-all": "^3.1.1"
  }
}
}
  35  
src/main.ts
@@ -1,8 +1,8 @@
import core from '@actions/core'
import axios from 'axios'
import { XMLBuilder, XMLParser } from 'fast-xml-parser'
import fs from 'fs'
import xmlFormat from 'xml-formatter'
import yargs from 'yargs'

interface Repository {
  id: string
@@ -133,8 +133,8 @@ async function parseMavenMetadata(
  )
}

async function main(args: any) {
  const content = fs.readFileSync(args.target, 'utf-8')
async function main(pomPath: string, ignorePackages: string) {
  const content = fs.readFileSync(pomPath, 'utf-8')

  const pom = await parsePom(content)

@@ -144,9 +144,9 @@ async function main(args: any) {
  for (const dependency of pom.dependencies) {
    console.log('[main]', 'Dependency:', JSON.stringify(dependency))
    if (
      args.ignorePackages.includes(
        dependency.groupId + '.' + dependency.artifactId
      )
      ignorePackages
        .split(',')
        .includes(dependency.groupId + '.' + dependency.artifactId)
    ) {
      console.log('[main]', 'This package is ignored.')
      continue
@@ -207,27 +207,27 @@
    format: true,
    indentBy: '    ',
    unpairedTags: ['?xml'],
    commentPropName: '#comment',
  })
    .build(pomXml)
    .replace(
      '<?xml version="1.0" encoding="UTF-8"></?xml>',
      '<?xml version="1.0" encoding="UTF-8"?>'
    )
    .replace(
      /<\/repositories>[\n ]*<repositories>/g,
      '</repository><repository>'
    )
    .replace(
      /<\/dependencies>[\n ]*<dependencies>/g,
      '</dependency><dependency>'
    )
    .replace('<repositories>', '<repositories><repository>')
    .replace('<dependencies>', '</repositories><dependencies><dependency>')
    .replace('</project>', '</dependencies></project>')

  fs.writeFileSync(
    args.target,
    pomPath,
    xmlFormat(xml, {
      collapseContent: true,
    }),
    'utf8'
  )
}

;(async () => {
  main(
    yargs
      .option('target', {
        description: 'pom.xml path',
        demandOption: true,
      })
      .option('ignore-packages', {
        description: 'Ignore packages (Comma separated)',
        type: 'array',
        coerce: (array) => {
          if (array === undefined) {
            return []
          }
          return array.flatMap((v: string) => v.split(','))
        },
      })
      .help().argv
  )
  const pomPath = core.getInput('pom-path')
  const ignorePackages = core.getInput('ignore-packages')
  main(pomPath, ignorePackages)
})()
Footer
© 2022 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Docs
Contact GitHub
Pricing
API
Training
Blog
About
Comparing zakwarlord7:v1.0.0...book000:v1.0.1 · zakwarlord7/pomxml-dep-update
Web searchCopy
Name: NodeJS with Grunt

on:
  push:
    branches: [ "master" ]
  pull_request:
    branches: [ "master" ]

jobs:
  build:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [14.x, 16.x, 18.x]
    
    steps:
    - uses: actions/checkout@v3

    - name: Use Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}

    - name: Build
      run: |
        npm install
        grunt
