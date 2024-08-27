/* eslint-env node */
/* eslint no-console:"off" */

const { dest, parallel, series, src, watch } = require('gulp');

const child_process = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const util = require('util');
const stream = require('stream/promises');

const sass = require('gulp-sass')(require('sass'));
const tildeImporter = require('node-sass-tilde-importer');
const rtlcss = require('gulp-rtlcss');
const sourcemaps = require('gulp-sourcemaps');
const autoprefixer = require('gulp-autoprefixer');
const concatPo = require('gulp-concat-po');
const exec = require('gulp-exec');
const merge = require('merge-stream');
const through2 = require('through2');
const Vinyl = require('vinyl');
const args = require('minimist')(process.argv.slice(2), { default: { 'generate-pot': 'always' } });
const rename = require('gulp-rename');

const STAFF_CSS_BASE = "koha-tmpl/intranet-tmpl/prog/css";
const OPAC_CSS_BASE = "koha-tmpl/opac-tmpl/bootstrap/css";

var CSS_BASE = args.view == "opac"
    ? OPAC_CSS_BASE
    : STAFF_CSS_BASE;

var sassOptions = {
    importer: tildeImporter,
    includePaths: [
        __dirname + '/node_modules',
        __dirname + '/../node_modules'
    ]
}

// CSS processing for development
function css(css_base) {
    css_base = css_base || CSS_BASE
    var stream = src(css_base + "/src/**/*.scss", { sourcemaps: true } );

    if (args.view == "opac") {
        stream = stream
        .pipe(sass(sassOptions).on('error', sass.logError))
        .pipe(autoprefixer())
        .pipe(dest(css_base))
        .pipe(rtlcss())
        .pipe(rename({
            suffix: '-rtl'
        })) // Append "-rtl" to the filename.
        .pipe(dest(css_base, { sourcemaps: "./maps" } ));
    } else {
        stream = stream
        .pipe(sass(sassOptions).on('error', sass.logError))
        .pipe(autoprefixer())
        .pipe(dest(css_base))
        .pipe(rtlcss())
        .pipe(rename({
            suffix: '-rtl'
        })) // Append "-rtl" to the filename.
        .pipe(dest(css_base, { sourcemaps: "/maps" } ));
    }

    return stream;
}

// CSS processing for production
function build(css_base) {
    css_base = css_base || CSS_BASE;
    sassOptions.outputStyle = "compressed";
    var stream = src(css_base + "/src/**/*.scss")
        .pipe(sass(sassOptions).on('error', sass.logError))
        .pipe(autoprefixer())
        .pipe(dest(css_base))
        .pipe(rtlcss())
        .pipe(rename({
            suffix: '-rtl'
        })) // Append "-rtl" to the filename.
        .pipe(dest(css_base));
    return stream;
}

function opac_css(){
    return css(OPAC_CSS_BASE);
}

function staff_css(){
    return css(STAFF_CSS_BASE);
}

const poTasks = {
    'marc-MARC21': {
        extract: po_extract_marc_marc21,
        create: po_create_marc_marc21,
        update: po_update_marc_marc21,
    },
    'marc-UNIMARC': {
        extract: po_extract_marc_unimarc,
        create: po_create_marc_unimarc,
        update: po_update_marc_unimarc,
    },
    'staff-prog': {
        extract: po_extract_staff,
        create: po_create_staff,
        update: po_update_staff,
    },
    'opac-bootstrap': {
        extract: po_extract_opac,
        create: po_create_opac,
        update: po_update_opac,
    },
    'pref': {
        extract: po_extract_pref,
        create: po_create_pref,
        update: po_update_pref,
    },
    'messages': {
        extract: po_extract_messages,
        create: po_create_messages,
        update: po_update_messages,
    },
    'messages-js': {
        extract: po_extract_messages_js,
        create: po_create_messages_js,
        update: po_update_messages_js,
    },
    'installer': {
        extract: po_extract_installer,
        create: po_create_installer,
        update: po_update_installer,
    },
    'installer-MARC21': {
        extract: po_extract_installer_marc21,
        create: po_create_installer_marc21,
        update: po_update_installer_marc21,
    },
    'installer-UNIMARC': {
        extract: po_extract_installer_unimarc,
        create: po_create_installer_unimarc,
        update: po_update_installer_unimarc,
    },
};

function getPoTasks () {
    let tasks = [];

    let all_tasks = Object.keys(poTasks);

    if (args.task) {
        tasks = [args.task].flat(Infinity);
    } else {
        return all_tasks;
    }

    let invalid_tasks = tasks.filter( function( el ) {
        return all_tasks.indexOf( el ) < 0;
    });

    if ( invalid_tasks.length ) {
        console.error("Invalid task");
        return [];
    }

    return tasks;
}

function po_extract_marc (type) {
    return src(`koha-tmpl/*-tmpl/*/en/**/*${type}*`, { read: false, nocase: true })
        .pipe(xgettext('misc/translator/xgettext.pl --charset=UTF-8 -F', `Koha-marc-${type}.pot`))
        .pipe(dest('misc/translator'))
}

function po_extract_marc_marc21 ()  { return po_extract_marc('MARC21') }
function po_extract_marc_unimarc () { return po_extract_marc('UNIMARC') }

function po_extract_staff () {
    const globs = [
        'koha-tmpl/intranet-tmpl/prog/en/**/*.tt',
        'koha-tmpl/intranet-tmpl/prog/en/**/*.inc',
        'koha-tmpl/intranet-tmpl/prog/en/xslt/*.xsl',
        '!koha-tmpl/intranet-tmpl/prog/en/**/*MARC21*',
        '!koha-tmpl/intranet-tmpl/prog/en/**/*UNIMARC*',
        '!koha-tmpl/intranet-tmpl/prog/en/**/*marc21*',
        '!koha-tmpl/intranet-tmpl/prog/en/**/*unimarc*',
    ];

    return src(globs, { read: false, nocase: true })
        .pipe(xgettext('misc/translator/xgettext.pl --charset=UTF-8 -F', 'Koha-staff-prog.pot'))
        .pipe(dest('misc/translator'))
}

function po_extract_opac () {
    const globs = [
        'koha-tmpl/opac-tmpl/bootstrap/en/**/*.tt',
        'koha-tmpl/opac-tmpl/bootstrap/en/**/*.inc',
        'koha-tmpl/opac-tmpl/bootstrap/en/xslt/*.xsl',
        '!koha-tmpl/opac-tmpl/bootstrap/en/**/*MARC21*',
        '!koha-tmpl/opac-tmpl/bootstrap/en/**/*UNIMARC*',
        '!koha-tmpl/opac-tmpl/bootstrap/en/**/*marc21*',
        '!koha-tmpl/opac-tmpl/bootstrap/en/**/*unimarc*',
    ];

    return src(globs, { read: false, nocase: true })
        .pipe(xgettext('misc/translator/xgettext.pl --charset=UTF-8 -F', 'Koha-opac-bootstrap.pot'))
        .pipe(dest('misc/translator'))
}

const xgettext_options = '--from-code=UTF-8 --package-name Koha '
    + '--package-version= -k -k__ -k__x -k__n:1,2 -k__nx:1,2 -k__xn:1,2 '
    + '-k__p:1c,2 -k__px:1c,2 -k__np:1c,2,3 -k__npx:1c,2,3 -kN__ '
    + '-kN__n:1,2 -kN__p:1c,2 -kN__np:1c,2,3 '
    + '-k -k$__ -k$__x -k$__n:1,2 -k$__nx:1,2 -k$__xn:1,2 '
    + '--force-po';

function po_extract_messages_js () {
    const globs = [
        'koha-tmpl/intranet-tmpl/prog/js/vue/**/*.vue',
        'koha-tmpl/intranet-tmpl/prog/js/**/*.js',
        'koha-tmpl/opac-tmpl/bootstrap/js/**/*.js',
    ];

    return src(globs, { read: false, nocase: true })
        .pipe(xgettext(`xgettext -L JavaScript ${xgettext_options}`, 'Koha-messages-js.pot'))
        .pipe(dest('misc/translator'))
}

function po_extract_messages () {
    const perlStream = src(['**/*.pl', '**/*.pm'], { read: false, nocase: true })
        .pipe(xgettext(`xgettext -L Perl ${xgettext_options}`, 'Koha-perl.pot'))

    const ttStream = src([
            'koha-tmpl/intranet-tmpl/prog/en/**/*.tt',
            'koha-tmpl/intranet-tmpl/prog/en/**/*.inc',
            'koha-tmpl/opac-tmpl/bootstrap/en/**/*.tt',
            'koha-tmpl/opac-tmpl/bootstrap/en/**/*.inc',
        ], { read: false, nocase: true })
        .pipe(xgettext('misc/translator/xgettext-tt2 --from-code=UTF-8', 'Koha-tt.pot'))

    const headers = {
        'Project-Id-Version': 'Koha',
        'Content-Type': 'text/plain; charset=UTF-8',
    };

    return merge(perlStream, ttStream)
        .pipe(concatPo('Koha-messages.pot', { headers }))
        .pipe(dest('misc/translator'))
}

function po_extract_pref () {
    return src('koha-tmpl/intranet-tmpl/prog/en/modules/admin/preferences/*.pref', { read: false })
        .pipe(xgettext('misc/translator/xgettext-pref', 'Koha-pref.pot'))
        .pipe(dest('misc/translator'))
}

function po_extract_installer () {
    const globs = [
        'installer/data/mysql/en/mandatory/*.yml',
        'installer/data/mysql/en/optional/*.yml',
    ];

    return src(globs, { read: false, nocase: true })
        .pipe(xgettext('misc/translator/xgettext-installer', 'Koha-installer.pot'))
        .pipe(dest('misc/translator'))
}

function po_extract_installer_marc (type) {
    const globs = `installer/data/mysql/en/marcflavour/${type}/**/*.yml`;

    return src(globs, { read: false, nocase: true })
        .pipe(xgettext('misc/translator/xgettext-installer', `Koha-installer-${type}.pot`))
        .pipe(dest('misc/translator'))
}

function po_extract_installer_marc21 ()  { return po_extract_installer_marc('MARC21') }

function po_extract_installer_unimarc ()  { return po_extract_installer_marc('UNIMARC') }

function po_create_type (type) {
    const access = util.promisify(fs.access);
    const exec = util.promisify(child_process.exec);

    const pot = `misc/translator/Koha-${type}.pot`;

    // Generate .pot only if it doesn't exist or --force-extract is given
    const extract = () => stream.finished(poTasks[type].extract());
    const p =
        args['generate-pot'] === 'always' ? extract() :
        args['generate-pot'] === 'auto' ? access(pot).catch(extract) :
        args['generate-pot'] === 'never' ? Promise.resolve(0) :
        Promise.reject(new Error('Invalid value for option --generate-pot: ' + args['generate-pot']))

    return p.then(function () {
        const languages = getLanguages();
        const promises = [];
        for (const language of languages) {
            const locale = language.split('-').filter(s => s.length !== 4).join('_');
            const po = `misc/translator/po/${language}-${type}.po`;

            const promise = access(po)
                .catch(() => exec(`msginit -o ${po} -i ${pot} -l ${locale} --no-translator`))
            promises.push(promise);
        }

        return Promise.all(promises);
    });
}

function po_create_marc_marc21 ()       { return po_create_type('marc-MARC21') }
function po_create_marc_unimarc ()      { return po_create_type('marc-UNIMARC') }
function po_create_staff ()             { return po_create_type('staff-prog') }
function po_create_opac ()              { return po_create_type('opac-bootstrap') }
function po_create_pref ()              { return po_create_type('pref') }
function po_create_messages ()          { return po_create_type('messages') }
function po_create_messages_js ()       { return po_create_type('messages-js') }
function po_create_installer ()         { return po_create_type('installer') }
function po_create_installer_marc21 ()  { return po_create_type('installer-MARC21') }
function po_create_installer_unimarc () { return po_create_type('installer-UNIMARC') }

function po_update_type (type) {
    const access = util.promisify(fs.access);
    const exec = util.promisify(child_process.exec);

    const pot = `misc/translator/Koha-${type}.pot`;

    // Generate .pot only if it doesn't exist or --force-extract is given
    const extract = () => stream.finished(poTasks[type].extract());
    const p =
        args['generate-pot'] === 'always' ? extract() :
        args['generate-pot'] === 'auto' ? access(pot).catch(extract) :
        args['generate-pot'] === 'never' ? Promise.resolve(0) :
        Promise.reject(new Error('Invalid value for option --generate-pot: ' + args['generate-pot']))

    return p.then(function () {
        const languages = getLanguages();
        const promises = [];
        for (const language of languages) {
            const po = `misc/translator/po/${language}-${type}.po`;
            promises.push(exec(`msgmerge --backup=off --no-wrap --quiet -F --update ${po} ${pot}`));
        }

        return Promise.all(promises);
    });
}

function po_update_marc_marc21 ()       { return po_update_type('marc-MARC21') }
function po_update_marc_unimarc ()      { return po_update_type('marc-UNIMARC') }
function po_update_staff ()             { return po_update_type('staff-prog') }
function po_update_opac ()              { return po_update_type('opac-bootstrap') }
function po_update_pref ()              { return po_update_type('pref') }
function po_update_messages ()          { return po_update_type('messages') }
function po_update_messages_js ()       { return po_update_type('messages-js') }
function po_update_installer ()         { return po_update_type('installer') }
function po_update_installer_marc21 ()  { return po_update_type('installer-MARC21') }
function po_update_installer_unimarc () { return po_update_type('installer-UNIMARC') }

const PLUGINS_BASE = "/kohadevbox/plugins";
const PLUGINS = []

if (args.plugins) {
    const identifyPluginFile = (file) => {
        const pluginFile = fs.readFileSync(file, 'utf8')
        const fileByLine = pluginFile.split(/\r?\n/)

        let pluginIdentified = false
        fileByLine.forEach(line => {
            if (line.includes("Koha::Plugins::Base")) {
                pluginIdentified = true
            }
        })
        return pluginIdentified
    }

    const collectPluginFiles = (fullPath) => {
        let files = []
        fs.readdirSync(fullPath).forEach(file => {
            const absolutePath = path.join(fullPath, file)
            if (fs.statSync(absolutePath).isDirectory()) {
                const filesFromNestedFolder = collectPluginFiles(absolutePath)
                filesFromNestedFolder && filesFromNestedFolder.forEach(file => {
                    files.push(file)
                })
            } else {
                return files.push(absolutePath)
            }
        })
        return files
    }

    function po_create_plugins(pluginData, type) {
        const access = util.promisify(fs.access);
        const exec = util.promisify(child_process.exec);

        const translatorDirCheck = fs.readdirSync(pluginData.bundlePath).includes('translator')
        if (!translatorDirCheck) {
            fs.mkdirSync(`${pluginData.bundlePath}/translator`)
        }
        const poDirCheck = fs.readdirSync(pluginData.bundlePath + '/translator').includes('po')
        if (!poDirCheck) {
            fs.mkdirSync(`${pluginData.bundlePath}/translator/po`)
        }

        const pot = `${pluginData.bundlePath}/translator/${pluginData.name}-${type}.pot`;

        // Generate .pot only if it doesn't exist or --force-extract is given
        const extract = () => stream.finished(poTasks[`${pluginData.name}-${type}`].extract());

        const p =
            args['generate-pot'] === 'always' ? extract() :
                args['generate-pot'] === 'auto' ? access(pot).catch(extract) :
                    args['generate-pot'] === 'never' ? Promise.resolve(0) :
                        Promise.reject(new Error('Invalid value for option --generate-pot: ' + args['generate-pot']))

        return p.then(function () {
            const languages = getLanguages();
            const promises = [];
            languages.forEach(language => {
                const locale = language.split('-').filter(s => s.length !== 4).join('_');
                const po = `${pluginData.bundlePath}/translator/po/${language}-${pluginData.name}-${type}.po`;

                const promise = access(po)
                    .catch(() => exec(`msginit -o ${po} -i ${pot} -l ${locale} --no-translator`))
                promises.push(promise);
            })
            return Promise.all(promises);
        })
    }

    function po_extract_plugins_js(pluginData) {
        const globs = [
            `${pluginData.directory}/**/*.js`,
            `${pluginData.directory}/**/*.vue`,
            `!${pluginData.directory}/**/node_modules/**/*`,
        ];

        return src(globs, { read: false, nocase: true })
            .pipe(xgettext(`xgettext -L JavaScript ${xgettext_options}`, `${pluginData.name}-js.pot`))
            .pipe(dest(`${pluginData.bundlePath}/translator`))
    }

    function po_extract_plugins_template(pluginData) {
        const globs = [
            `${pluginData.directory}/**/*.tt`,
            `${pluginData.directory}/**/*.inc`,
            `!${pluginData.directory}/**/node_modules/**/*`,
        ];

        return src(globs, { read: false, nocase: true })
            .pipe(xgettext('misc/translator/xgettext.pl --charset=UTF-8 -F', `${pluginData.name}-template.pot`))
            .pipe(dest(`${pluginData.bundlePath}/translator`))
    }

    function po_update_plugins(pluginData, type) {
        const access = util.promisify(fs.access);
        const exec = util.promisify(child_process.exec);

        const pot = `${pluginData.bundlePath}/translator/${pluginData.name}-${type}.pot`;

        // Generate .pot only if it doesn't exist or --force-extract is given
        const extract = () => stream.finished(poTasks[`${pluginData.name}-${type}`].extract());
        const p =
            args['generate-pot'] === 'always' ? extract() :
                args['generate-pot'] === 'auto' ? access(pot).catch(extract) :
                    args['generate-pot'] === 'never' ? Promise.resolve(0) :
                        Promise.reject(new Error('Invalid value for option --generate-pot: ' + args['generate-pot']))

        return p.then(function () {
            const languages = getLanguages();
            const promises = [];
            languages.forEach(language => {
                const po = `${pluginData.bundlePath}/translator/po/${language}-${pluginData.name}-${type}.po`;
                promises.push(exec(`msgmerge --backup=off --no-wrap --quiet -F --update ${po} ${pot}`));
            })

            return Promise.all(promises);
        });
    }

    // Remove all tasks except for plugins
    Object.keys(poTasks).forEach(task => {
        delete poTasks[task]
    })

    const pluginNames = fs.readdirSync(PLUGINS_BASE);
    pluginNames.forEach(plugin => {
        const pluginFiles = collectPluginFiles(`${PLUGINS_BASE}/${plugin}/Koha`)
        let pluginFilePath
        pluginFiles.forEach(file => {
            const pluginFile = identifyPluginFile(file)
            if (pluginFile) {
                pluginFilePath = file.split('.')[0]
            }
        })
        const name = pluginFilePath.split('/').pop()
        const pluginData = {
            name,
            bundlePath: pluginFilePath,
            directory: `${PLUGINS_BASE}/${plugin}`,
        }
        PLUGINS.push(pluginData)

        function po_extract_js () { return po_extract_plugins_js(pluginData) }
        function po_create_js () { return po_create_plugins(pluginData, 'js') }
        function po_update_js () { return po_update_plugins(pluginData, 'js') }
        function po_extract_template () { return po_extract_plugins_template(pluginData) }
        function po_create_template () { return po_create_plugins(pluginData, 'template') }
        function po_update_template () { return po_update_plugins(pluginData, 'template') }
        
        poTasks[`${name}-js`] = {
            extract: po_extract_js,
            create: po_create_js,
            update: po_update_js,
        }
        poTasks[`${name}-template`] = {
            extract: po_extract_template,
            create: po_create_template,
            update: po_update_template,
        }
    })
}

/**
 * Gulp plugin that executes xgettext-like command `cmd` on all files given as
 * input, and then outputs the result as a POT file named `filename`.
 * `cmd` should accept -o and -f options
 */
function xgettext (cmd, filename) {
    const filenames = [];

    function transform (file, encoding, callback) {
        filenames.push(path.relative(file.cwd, file.path));
        callback();
    }

    function flush (callback) {
        fs.mkdtemp(path.join(os.tmpdir(), 'koha-'), (err, folder) => {
            const outputFilename = path.join(folder, filename);
            const filesFilename = path.join(folder, 'files');
            fs.writeFile(filesFilename, filenames.join(os.EOL), err => {
                if (err) return callback(err);

                const command = `${cmd} -o ${outputFilename} -f ${filesFilename}`;
                child_process.exec(command, err => {
                    if (err) return callback(err);

                    fs.readFile(outputFilename, (err, data) => {
                        if (err) return callback(err);

                        const file = new Vinyl();
                        file.path = path.join(file.base, filename);
                        file.contents = data;
                        callback(null, file);
                        fs.rmSync(folder, { recursive: true });
                    });
                });
            });
        })
    }

    return through2.obj(transform, flush);
}

/**
 * Return languages selected for PO-related tasks
 *
 * This can be either languages given on command-line with --lang option, or
 * all the languages found in misc/translator/po otherwise
 */
function getLanguages () {
    if (Array.isArray(args.lang)) {
        return args.lang;
    }

    if (args.lang) {
        return [args.lang];
    }

    const filenames = fs.readdirSync('misc/translator/po/')
        .filter(filename => filename.endsWith('-installer.po'))
        .filter(filename => !filename.startsWith('.'))

    const re = new RegExp('-installer.po');
    languages = filenames.map(filename => filename.replace(re, ''))

    return Array.from(new Set(languages));
}

exports.build = function(next){build(); next();};
exports.css = function(next){css(); next();};
exports.opac_css = opac_css;
exports.staff_css = staff_css;
exports.watch = function () {
    watch(OPAC_CSS_BASE + "/src/**/*.scss", series('opac_css'));
    watch(STAFF_CSS_BASE + "/src/**/*.scss", series('staff_css'));
};

if (args['_'][0].match("po:") && !fs.existsSync('misc/translator/po')) {
    console.log("misc/translator/po does not exist. You should clone koha-l10n there. See https://wiki.koha-community.org/wiki/Translation_files for more details.");
    process.exit(1);
}

const poTypes = getPoTasks();

exports['po:create'] = parallel(...poTypes.map(type => poTasks[type].create));
exports['po:update'] = parallel(...poTypes.map(type => poTasks[type].update));
exports['po:extract'] = parallel(...poTypes.map(type => poTasks[type].extract));
