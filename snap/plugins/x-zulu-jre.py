# -*- Mode:Python; indent-tabs-mode:nil; tab-width:4 -*-
import snapcraft
import logging

from snapcraft.plugins import dump

logger = logging.getLogger(__name__)

# Map ZULU releases to target architectures
_ZULU_RELEASE_MAP = {
    'armhf': 'https://www.azul.com/downloads/zulu/zdk-8-ga-linux_aarch32hf.tar.gz',
    'amd64': 'https://www.azul.com/downloads/zulu/zdk-8-ga-linux_x64.tar.gz'
}

class JavaRuntimePlugin(snapcraft.BasePlugin):

    @classmethod
    def schema(cls):
        schema = super().schema()
        schema['properties']['zulu'] = {
            'type': 'object',
            'default': {}
        }

        if 'source' in schema['required']:
            del schema['required']

        return schema

    @classmethod
    def get_build_properties(cls):
        # Inform Snapcraft of the properties associated with building. If these
        # change in the YAML Snapcraft will consider the build step dirty.
        return super().get_build_properties() + ['zulu']

    @classmethod
    def get_pull_properties(cls):
        # Inform Snapcraft of the properties associated with pulling. If these
        # change in the YAML Snapcraft will consider the pull step dirty.
        return super().get_pull_properties() + ['zulu']

    def __init__(self, name, options, project):
        super().__init__(name, options, project)
        # we want to be clever and filter schema based on architecture, so snapcraft
        # handles rest for us.
        # If we have zulu package defined for target architecture use it, and clean stage-packages, build-packages
        # If we have no zulu package defined, use openjdk-8-jre instead
        self.zulu = True
        self.build_packages = []
        self.stage_packages = []
        urls = {f: self.options.zulu[f] for f in self.options.zulu}
        if project.deb_arch in urls.keys():
             logger.info('Using zulu jre overide from snapcraft.yaml, arch:{!r}, url: {!r}'.format(project.deb_arch, urls[project.deb_arch]))
             self.zulu = True
             self.source = urls[project.deb_arch]
             setattr(self.options, 'source', self.source)
        elif project.deb_arch in _ZULU_RELEASE_MAP.keys():
             logger.info('Using zulu java runtime, arch:{!r}, url: {!r}'.format(project.deb_arch, _ZULU_RELEASE_MAP[project.deb_arch]))
             self.zulu = True
             self.source = _ZULU_RELEASE_MAP[project.deb_arch]
             setattr(self.options, 'source', self.source)
        else:
             logger.info('We do not have zulu release for {!r}, defaulting to openjdk runtime'.format(self.project.deb_arch))
             self.zulu = False
             self.stage_packages.append('openjdk-8-jre')
             self.build_packages.append('openjdk-8-jre-headless')

    def pull(self):
        super().pull()

        # if we are using zulu, pull it here
        if self.zulu:
            logger.info('Pulling zulu ...')
            snapcraft.sources.get(self.sourcedir, None, self.options)

    def clean_pull(self):
        super().clean_pull()

    def build(self):
        super().build()
        if self.zulu:
            snapcraft.file_utils.link_or_copy_tree(
                self.builddir, self.installdir,
                copy_function=lambda src, dst: dump._link_or_copy(src, dst, self.installdir))

    def enable_cross_compilation(self):
        pass

    def env(self, root):
        # set env based on java runtime we are using
        if self.zulu:
            return ['JAVA_HOME=%s/jre' % root,
                    'PATH=%s/jre/bin:$PATH' % root]
        else:
            return ['JAVA_HOME=%s/usr/lib/jvm/java-8-openjdk-%s' % (root, self.project.deb_arch),
                    'PATH=%s/usr/lib/jvm/java-8-openjdk-%s/bin:$PATH' % (root, self.project.deb_arch)]

    def snap_fileset(self):
        # Cut out jdk/zulu-jdk bits which are not needed, we want just jre
        if self.zulu:
            return (['-bin',
                     '-demo',
                     '-include',
                     '-lib',
                     '-man',
                     '-sample',
                     '-src.zip',
                     '-jre/lib/aarch32/client/libjvm.diz',
                     '-openhab-control',
                     '-connect-interfaces',
                     ])
        else:
            return (['-lib',
                     '-var',
                     '-usr/include',
                     '-usr/lib/gcc',
                     '-usr/lib/ssl',
                     '-usr/lib/X11',
                     '-usr/lib/*-linux-gnu/',
                     '-usr/sbin',
                     '-usr/shared',
                     ])
