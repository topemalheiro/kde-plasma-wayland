project('wayland-protocols',
	version: '1.48',
	meson_version: '>= 0.58.0',
	license: 'MIT/Expat',
)

wayland_protocols_version = meson.project_version()

fs = import('fs')

dep_scanner = dependency('wayland-scanner',
    version: get_option('tests') ? '>=1.25.0' : '>=1.20.0',
    native: true,
    fallback: 'wayland'
)
prog_scanner = find_program(dep_scanner.get_variable(pkgconfig: 'wayland_scanner', internal: 'wayland_scanner'))

stable_protocols = {
	'linux-dmabuf': {'v1': []},
	'presentation-time': {'': []},
	'tablet': {'v2': []},
	'viewporter': {'': []},
	'xdg-shell': {'': []},
}

unstable_protocols = {
	'fullscreen-shell': {'v1': []},
	'idle-inhibit': {'v1': []},
	'input-method': {'v1': []},
	'input-timestamps': {'v1': []},
	'keyboard-shortcuts-inhibit': {'v1': []},
	'linux-dmabuf': {'v1': []},
	'linux-explicit-synchronization': {'v1': []},
	'pointer-constraints': {'v1': []},
	'pointer-gestures': {'v1': []},
	'primary-selection': {'v1': []},
	'relative-pointer': {'v1': []},
	'tablet': {'v1': [], 'v2': []},
	'text-input': {'v1': [], 'v3': []},
	'xdg-decoration': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xdg-foreign': {'v1': [], 'v2': []},
	'xdg-output': {'v1': []},
	'xdg-shell': {'v5': [], 'v6': []},
	'xwayland-keyboard-grab': {'v1': []},
}

staging_protocols = {
	'alpha-modifier': {'v1': []},
	'color-management': {'v1': []},
	'color-representation': {'v1': []},
	'commit-timing': {'v1': []},
	'content-type': {'v1': []},
	'cursor-shape': {'v1': ['stable/tablet/tablet-v2.xml']},
	'drm-lease': {'v1': []},
	'ext-background-effect': {'v1': []},
	'ext-data-control': {'v1': []},
	'ext-foreign-toplevel-list': {'v1': []},
	'ext-idle-notify': {'v1': []},
	'ext-image-capture-source': {'v1': [
		'staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml',
	]},
	'ext-image-copy-capture': {'v1': [
		'staging/ext-image-capture-source/ext-image-capture-source-v1.xml',
		'staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml',
	]},
	'ext-session-lock': {'v1': []},
	'ext-transient-seat': {'v1': []},
	'ext-workspace': {'v1': []},
	'fifo': {'v1': []},
	'fractional-scale': {'v1': []},
	'linux-drm-syncobj': {'v1': []},
	'pointer-warp': {'v1': []},
	'security-context': {'v1': []},
	'single-pixel-buffer': {'v1': []},
	'tearing-control': {'v1': []},
	'xdg-activation': {'v1': []},
	'xdg-dialog': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xdg-session-management': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xdg-system-bell': {'v1': []},
	'xdg-toplevel-drag': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xdg-toplevel-icon': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xdg-toplevel-tag': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xwayland-shell': {'v1': []},
}

experimental_protocols = {
	'xx-cutouts': {'v1': []},
	'xx-input-method': {'v2': []},
	'xx-keyboard-filter': {'v1': [
		'experimental/xx-input-method/xx-input-method-v2.xml',
	]},
	'xx-session-management': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
	'xx-text-input': {'v3': []},
	'xx-zones': {'v1': ['stable/xdg-shell/xdg-shell.xml']},
}

protocol_files = []
installed_protocol_files = []
protocol_deps = {}

stable_protocol_files = []
foreach name, versions : stable_protocols
	foreach version, deps : versions
		if version == ''
			protocol_file = 'stable/@0@/@0@.xml'.format(name)
		else
			protocol_file = 'stable/@0@/@0@-@1@.xml'.format(name, version)
		endif
		stable_protocol_files += [protocol_file]
		if deps.length() > 0
			protocol_deps += {protocol_file: deps}
		endif
	endforeach
endforeach
installed_protocol_files += stable_protocol_files
protocol_files += stable_protocol_files

staging_protocol_files = []
foreach name, versions : staging_protocols
	foreach version, deps : versions
		protocol_file = 'staging/@0@/@0@-@1@.xml'.format(name, version)
		staging_protocol_files += [protocol_file]
		if deps.length() > 0
			protocol_deps += {protocol_file: deps}
		endif
	endforeach
endforeach
installed_protocol_files += staging_protocol_files
protocol_files += staging_protocol_files

unstable_protocol_files = []
foreach name, versions : unstable_protocols
	foreach version, deps : versions
		protocol_file = 'unstable/@0@/@0@-unstable-@1@.xml'.format(name, version)
		unstable_protocol_files += [protocol_file]
		if deps.length() > 0
			protocol_deps += {protocol_file: deps}
		endif
	endforeach
endforeach
installed_protocol_files += unstable_protocol_files
protocol_files += unstable_protocol_files

experimental_protocol_files = []
foreach name, versions : experimental_protocols
	foreach version, deps : versions
		protocol_file = 'experimental/@0@/@0@-@1@.xml'.format(name, version)
		experimental_protocol_files += [protocol_file]
		if deps.length() > 0
			protocol_deps += {protocol_file: deps}
		endif
	endforeach
endforeach
protocol_files += experimental_protocol_files

# Check that each protocol has a README
foreach protocol_file : protocol_files
	dir = fs.parent(protocol_file)
	if not fs.is_file(dir + '/README')
		error('Missing README in @0@'.format(protocol_file))
	endif
endforeach

foreach protocol_file : installed_protocol_files
	protocol_install_dir = fs.parent(join_paths(
		get_option('datadir'),
		'wayland-protocols',
		protocol_file,
	))
	install_data(
		protocol_file,
		install_dir: protocol_install_dir,
	)
endforeach

include_dirs = []
headers = []
if dep_scanner.version().version_compare('>=1.22.90')
	subdir('include/wayland-protocols')
	include_dirs = ['include']
endif

pkgconfig = import('pkgconfig')

pkgconfig.generate(
	filebase: 'wayland-protocols',
	name: 'Wayland Protocols',
	description: 'Wayland protocol files',
	dataonly: true,
	variables: {
		'prefix': get_option('prefix'),
		'includedir': '${prefix}/@0@'.format(get_option('includedir')),
		'datarootdir': '${prefix}/@0@'.format(get_option('datadir')),
		'pkgdatadir': '${pc_sysrootdir}${datarootdir}/wayland-protocols'
	},
	uninstalled_variables: {
		'includedir': meson.current_build_dir() / 'include',
		'pkgdatadir': meson.project_source_root(),
	},
)

wayland_protocols = declare_dependency(
	include_directories: include_dirs,
	variables: {
		'pkgdatadir': meson.project_source_root(),
	},
	sources: headers,
)

meson.override_dependency('wayland-protocols', wayland_protocols)

if get_option('tests')
	subdir('tests')
endif

summary({
	'Headers': include_dirs.length() > 0,
}, bool_yn: true)
