/**
 * Copyright (c) 2010-2024 Contributors to the openHAB project
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0
 *
 * SPDX-License-Identifier: EPL-2.0
 */
import java.nio.file.Files
import java.nio.file.Paths
import groovy.xml.XmlNodePrinter
import groovy.xml.XmlParser

def baseDir = Paths.get(getClass().protectionDomain.codeSource.location.toURI()).toAbsolutePath()
def xmlDir = baseDir.resolveSibling("target/addon-xml")

// Read the addons.xml containing the addon info of openhab-addons
def addonsXmlPath = xmlDir.resolve("addons.xml")
println "Reading: ${addonsXmlPath}"
def addonsXml = Files.readString(addonsXmlPath)
def header = addonsXml.substring(0, addonsXml.indexOf("-->") + 4)
def addonInfoList = new XmlParser().parseText(addonsXml)

// Read and append the addon info in addon.xml of other repositories
Files.walk(xmlDir).forEach(path -> {
    if (Files.isRegularFile(path) && "addon.xml" == path.getFileName().toString()) {
        println "Reading: ${path}"
        def addonInfo = new XmlParser().parse(Files.newBufferedReader(path))
        addonInfoList.children().get(0).append(addonInfo)
    }
})

// Write the combined addon info to addons.xml
assemblyXmlPath = baseDir.resolveSibling("target/assembly/runtime/etc/addons.xml")
println "Writing: ${assemblyXmlPath} (${addonInfoList.addons.'*'.size()} add-ons)"

PrintWriter pw = new PrintWriter(Files.newOutputStream(assemblyXmlPath));
pw.append(header)
XmlNodePrinter nodePrinter = new XmlNodePrinter(pw, "\t");
nodePrinter.setPreserveWhitespace(true);
nodePrinter.print(addonInfoList);
