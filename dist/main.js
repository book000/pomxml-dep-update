"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const core_1 = __importDefault(require("@actions/core"));
const axios_1 = __importDefault(require("axios"));
const fast_xml_parser_1 = require("fast-xml-parser");
const fs_1 = __importDefault(require("fs"));
const xml_formatter_1 = __importDefault(require("xml-formatter"));
const MvnCentralRepository = {
    id: 'mvncentral',
    url: 'https://repo1.maven.org/maven2/',
};
async function parsePom(content) {
    const parser = new fast_xml_parser_1.XMLParser();
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
        const response = await axios_1.default.get(url);
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
    const content = await axios_1.default.get(url);
    const parser = new fast_xml_parser_1.XMLParser({
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
    const content = fs_1.default.readFileSync(pomPath, 'utf-8');
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
    const parser = new fast_xml_parser_1.XMLParser({
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
    const xml = new fast_xml_parser_1.XMLBuilder({
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
    fs_1.default.writeFileSync(pomPath, (0, xml_formatter_1.default)(xml, {
        collapseContent: true,
    }), 'utf8');
}
;
(async () => {
    const pomPath = core_1.default.getInput('pom-path');
    const ignorePackages = core_1.default.getInput('ignore-packages');
    main(pomPath, ignorePackages);
})();
//# sourceMappingURL=main.js.map