import axios from 'axios'
import { XMLBuilder, XMLParser } from 'fast-xml-parser'
import fs from 'fs'
import xmlFormat from 'xml-formatter'
import yargs from 'yargs'

interface Repository {
  id: string
  url: string
}

interface Dependency {
  groupId: string
  artifactId: string
  version: string
}

interface Pom {
  repositories: Repository[]
  dependencies: Dependency[]
}

const MvnCentralRepository: Repository = {
  id: 'mvncentral',
  url: 'https://repo1.maven.org/maven2/',
}

async function parsePom(content: string): Promise<Pom> {
  const parser = new XMLParser()
  const pomXml = parser.parse(content)

  const repositories: Repository[] = pomXml.project.repositories.repository
  const dependencies: Dependency[] = pomXml.project.dependencies.dependency

  return {
    repositories,
    dependencies,
  }
}

async function existsUrl(url: string) {
  console.log('[existsUrl]', 'url:', url)
  try {
    const response = await axios.get(url)
    console.log('[existsUrl]', 'response:', response.status)
    return response.status === 200
  } catch (error) {
    return false
  }
}

async function findAsync<T>(
  array: T[],
  predicate: (t: T) => Promise<boolean>
): Promise<T | undefined> {
  for (const t of array) {
    if (await predicate(t)) {
      return t
    }
  }
  return undefined
}

function getMavenMetadataXmlUrl(
  repository: Repository,
  dependency: Dependency
) {
  return (
    repository.url +
    (
      dependency.groupId.replace(/\./g, '/') +
      '/' +
      dependency.artifactId +
      '/maven-metadata.xml'
    ).replace(/\/\//g, '/')
  )
}

async function getDependencyRepo(
  repository: Repository[],
  dependency: Dependency
) {
  const depRepo = await findAsync(
    [...repository, MvnCentralRepository],
    async (repository: Repository): Promise<boolean> => {
      const url = getMavenMetadataXmlUrl(repository, dependency)
      const bool = await existsUrl(url)
      console.log('[getDependencyRepo]', url, bool)
      return bool
    }
  )
  if (depRepo) {
    return depRepo
  }
  return null
}
class MavenMetadata {
  constructor(
    public groupId: string,
    public artifactId: string,
    public latestVersion: string,
    public versions: string[]
  ) {
    this.groupId = groupId
    this.artifactId = artifactId
    this.latestVersion = latestVersion
    this.versions = versions
  }
}

async function parseMavenMetadata(
  repository: Repository,
  dependency: Dependency
): Promise<MavenMetadata> {
  const url = getMavenMetadataXmlUrl(repository, dependency)
  console.log('[parseMavenMetadata]', 'maven metadata url:', url)
  const content = await axios.get(url)

  const parser = new XMLParser({
    parseTagValue: false,
    parseAttributeValue: false,
  })
  const metadata = parser.parse(content.data)
  return new MavenMetadata(
    metadata.metadata.groupId,
    metadata.metadata.artifactId,
    metadata.metadata.versioning.latest !== undefined
      ? metadata.metadata.versioning.latest
      : metadata.metadata.versioning.release !== undefined
      ? metadata.metadata.versioning.release
      : null,
    metadata.metadata.versioning.versions.version
  )
}

async function main(args: any) {
  const content = fs.readFileSync(args.target, 'utf-8')

  const pom = await parsePom(content)

  console.log(pom.repositories)
  console.log(pom.dependencies)

  for (const dependency of pom.dependencies) {
    console.log('[main]', 'Dependency:', JSON.stringify(dependency))
    if (
      args.ignorePackages.includes(
        dependency.groupId + '.' + dependency.artifactId
      )
    ) {
      console.log('[main]', 'This package is ignored.')
      continue
    }
    const repository = await getDependencyRepo(pom.repositories, dependency)
    if (!repository) {
      console.warn('[main]', 'Dependency repo:', 'Not found')
      continue
    }
    console.log('[main]', 'Dependency repo:', JSON.stringify(repository))

    const metadata = await parseMavenMetadata(repository, dependency)
    console.log('[main]', 'Dependency metadata:', JSON.stringify(metadata))
    if (metadata.latestVersion === null) {
      console.warn('[main]', 'Dependency latest version:', 'Not found')
      continue
    }
    console.log('[main]', 'Dependency latest version:', metadata.latestVersion)
    if (metadata.latestVersion === dependency.version) {
      console.log('[main]', 'Dependency latest version:', 'Latest version')
      continue
    }
    console.log('[main]', 'Dependency latest version:', 'New version found')

    const replaceDep = pom.dependencies.find((d) => d === dependency)
    if (!replaceDep) {
      continue
    }
    replaceDep.version = metadata.latestVersion
    pom.dependencies.splice(
      pom.dependencies.findIndex((d) => d === dependency),
      1,
      replaceDep
    )
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
  })
  const pomXml = parser.parse(content)

  pomXml.project.repositories = pom.repositories
  pomXml.project.dependencies = pom.dependencies

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
})()
