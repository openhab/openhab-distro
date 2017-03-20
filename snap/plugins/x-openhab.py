# -*- Mode:Python; indent-tabs-mode:nil; tab-width:4 -*-
import os
import fileinput
import sys
import snapcraft
import logging
import shutil
import platform

from snapcraft.plugins import jdk, maven, dump
from snapcraft.internal import sources
from xml.etree import ElementTree

logger = logging.getLogger(__name__)

class OpenHabPlugin(snapcraft.BasePlugin):

    def __init__(self, name, options, project):
        super().__init__(name, options, project)
        self.build_packages.append('maven')
        self.jredir = os.path.join(self.partdir, 'jre')

    def _use_proxy(self):
        return any(k in os.environ for k in ('http_proxy', 'https_proxy'))

    def enable_cross_compilation(self):
        pass

    def build(self):
        snapcraft.BasePlugin.build(self)

        mvn_cmd = ['mvn','-f','distributions/openhab/pom.xml', 'package']
        if self._use_proxy():
            settings_path = os.path.join(self.partdir, 'm2', 'settings.xml')
            maven._create_settings(settings_path)
            mvn_cmd += ['-s', settings_path]

        if platform.machine() == 'armv7l':
            logger.warning('Setting up zulu jre for maven build')
            os.environ['JAVA_HOME'] = os.path.join(self.jredir, 'jre')
            os.environ['PATH'] = os.path.join(self.jredir, 'bin') + os.environ.get('PATH', 'not-set')

        self.run(mvn_cmd, self.sourcedir)

        tree = ElementTree.parse(os.path.join(self.sourcedir, 'distributions/openhab/pom.xml' ))
        root = tree.getroot()
        parent = root.find('{http://maven.apache.org/POM/4.0.0}parent')
        version = parent.find('{http://maven.apache.org/POM/4.0.0}version').text

        dist_package = os.path.join(self.sourcedir, 'distributions/openhab/target/openhab-' + version + '.tar.gz')

        sources.Tar(dist_package, self.builddir).pull()
        snapcraft.file_utils.link_or_copy_tree(
            self.builddir, self.installdir,
            copy_function=lambda src, dst: dump._link_or_copy(src, dst,
                                                         self.installdir))
        self._modify_oh2_dir()
        self._modify_setenv()
        self._fix_instance_path()

    def pull(self):
        super().pull()
        if platform.machine() == 'armv7l':
            logger.warning('Running on armhf host, use zulu jre for maven')
            os.makedirs(self.jredir, exist_ok=True)
            class Options:
                source='https://www.azul.com/downloads/zulu/zdk-8-ga-linux_aarch32hf.tar.gz'

            snapcraft.sources.get(self.jredir, None, Options())

    def _modify_oh2_dir(self):
        logger.warning('Patching ' + self.installdir + '/runtime/bin/oh2_dir_layout')
        self._replaceAll(self.installdir+"/runtime/bin/oh2_dir_layout", "${OPENHAB_HOME}/conf", "${SNAP_DATA}/conf")
        self._replaceAll(self.installdir+"/runtime/bin/oh2_dir_layout", "${OPENHAB_HOME}/userdata", "${SNAP_DATA}/userdata")

    def _modify_setenv(self):
        logger.warning('Patching ' + self.installdir + '/runtime/bin/setenv')
        self._replaceAll(self.installdir+"/runtime/bin/setenv","-Dopenhab.logdir=${OPENHAB_LOGDIR}","-Dopenhab.logdir=${OPENHAB_LOGDIR}\n  -Duser.home=${SNAP_DATA}")

    def _fix_instance_path(self):
        logger.warning('Patching ' + self.installdir + '/runtime/bin/client')
        self._replaceAll(self.installdir+"/runtime/bin/client", "${KARAF_HOME}/instances", "${SNAP_DATA}/karaf/instances")
        logger.warning('Patching ' + self.installdir + '/runtime/bin/instance')
        self._replaceAll(self.installdir+"/runtime/bin/instance", "${KARAF_HOME}/instances", "${SNAP_DATA}/karaf/instances")
        logger.warning('Patching ' + self.installdir + '/runtime/bin/karaf')
        self._replaceAll(self.installdir+"/runtime/bin/karaf", "${KARAF_HOME}/instances", "${SNAP_DATA}/karaf/instances")
        logger.warning('Patching ' + self.installdir + '/runtime/bin/shell')
        self._replaceAll(self.installdir+"/runtime/bin/shell", "${KARAF_HOME}/instances", "${SNAP_DATA}/karaf/instances")

    def _replaceAll(self,filePath,searchExp,replaceExp):
        for line in fileinput.input(filePath, inplace=1):
             if searchExp in line:
                 line = line.replace(searchExp,replaceExp)
             sys.stdout.write(line)
