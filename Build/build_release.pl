#***********************************************************************
#
# Name:   build_release.pl
#
# $Revision: 2443 $
# $URL: svn://10.36.148.185/WPSS_Tool/Validator_GUI/Tools/build_release.pl $
# $Date: 2022-12-16 13:40:48 -0500 (Fri, 16 Dec 2022) $
#
# Synopsis: build_release.pl [ Windows | Linux ]
#
#   where: Windows - create Windows release (default)
#          Linux - create Linux release
#
# This script is for building a release of the tool from the github
# repository.
#
#***********************************************************************

use strict;
use FindBin;
use File::Basename;
use File::Copy;
use File::Path;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Archive::Zip;

#
# Global variables
#
my ($dest) = 'C:\WPSS_Tool';
my ($src) = 'C:\Users\irwink\Documents\svnroot\WPSS_Tool';
my (@top_level_dirs) = qw(bin bin/epubcheck bin/epubcheck/lib conf
                          documents documents/licenses
                          lib
                          lib/CLI LM lib/CSS lib/CSS/Adaptor
                          lib/CSS/Parse lib/GUI lib/LWP
                          lib/LWP/RobotUA lib/Text
                          profiles python results);
my ($dir, @files, $file, $tar_file, $zip_file, $member);
my ($extractName, $arg, $program_dir, $repository_dir, $distribution_dir);
my ($platform) = "Windows";

#
# Get our program directory, where we find the source files
#
$program_dir  = $FindBin::RealBin;
$repository_dir = dirname($program_dir);
$distribution_dir = "$repository_dir/distribution";
$src = $repository_dir;
chdir($repository_dir);
if ( ! -d $distribution_dir ) {
   mkdir($distribution_dir) ||
        die "Failed to create distribution directory $distribution_dir";
}

#
# Check arguments
#
while ( @ARGV ) {
    $arg = shift @ARGV;
    if ( $arg =~ /Linux/i ) {
        $platform = "Linux";
        $dest .= "_Linux";
    }
}
#
# Add platform specific directories
#
if ( $platform eq "Windows" ) {
    push(@top_level_dirs, "nsgmls");
    $distribution_dir = "$distribution_dir/WPSS_Tool";
}
else{
    push(@top_level_dirs, "Win32");
    $distribution_dir = "$distribution_dir/WPSS_Tool_Linux";
}

#
# Remove any existing plaform specific distribution directory
#
if ( -d $distribution_dir ) {
    print "Remove directory $distribution_dir\n";
    rmtree($distribution_dir) ||
      die "Failed to rmtree directory $distribution_dir\n";
    sleep(2);
}
mkdir($distribution_dir) ||
    die "Failed to create distribution directory $distribution_dir";
$dest = $distribution_dir;

#
# Check for source directory
#
if ( -d $src ) {
    print "Have source directory $src\n";
}

#
# Create top level directories
#
foreach $dir (@top_level_dirs) {
    print "Create directory $dest/$dir\n";
    mkdir("$dest/$dir") ||
      die "Failed to create directory $dest/$dir\n";
}

#
# Copy CLF Check files
#
chdir("$src/CLF_Check");
print "Copy CLF_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}

@files = qw(clf_testcase_url.config so_clf_check.config);
for $file (@files) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}

#
# Copy Content Check files
#
chdir("$src/Content_Check");
print "Copy Content_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("language_map.txt", "$dest/LM/language_map.txt") ||
    die "Failed to copy language_map.txt to $dest/LM/language_map.txt\n";
chdir("$src/Content_Check/LM");
for $file (<*.lm>) {
    copy("$file", "$dest/LM/$file") ||
        die "Failed to copy $file to $dest/LM/$file, $!\n";
}
chdir("$src/Content_Check");
@files = qw(content_testcase_url.config so_content_check.config);
for $file (@files) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
copy("Lingua-EN-Fathom.zip", "$dest/lib/Lingua-EN-Fathom.zip") ||
        die "Failed to copy Lingua-EN-Fathom.zip to $dest/conf/Lingua-EN-Fathom.zip\n";
chdir("$dest/lib/");
$zip_file = Archive::Zip->new("Lingua-EN-Fathom.zip");
$zip_file->extractTree();


#
# Copy Crawler
#
chdir("$src/Crawler");
print "Copy Crawler files\n";
@files = qw(crawler.pm crawler_phantomjs.pm crawler_puppeteer.pm);
for $file (@files) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("lwp_robotua_cached.pm", "$dest/lib/LWP/RobotUA/Cached.pm") ||
    die "Failed to copy lwp_robotua_cached.pm to $dest/lib/LWP/RobotUA/Cached.pm\n";
for $file (<*.js>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
if ( $platform eq "Windows" ) {
    for $file (<*.bat>) {
        copy("$file", "$dest/bin/$file") ||
            die "Failed to copy $file to $dest/bin/$file\n";
    }
    chdir("$src/Crawler/Windows");
    for $file (<*.exe>) {
        copy("$file", "$dest/bin/$file") ||
            die "Failed to copy $file to $dest/bin/$file\n";
    }
}
if ( $platform eq "Linux" ) {
    chdir("$src/Crawler/Linux");
    copy("phantomjs", "$dest/bin/$file") ||
        die "Failed to copy phantomjs to $dest/bin/phantomjs\n";
}
chdir("$src/Crawler/Docs");
@files = ("phantomjs_license.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy CSS_Validate
#
chdir("$src/CSS_Validate");
print "Copy CSS_Validate files\n";
for $file (<*.jar>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
chdir("$src/CSS_Validate/Docs");
@files = qw(commons_license.txt jigsaw_copyright.txt tagsoup_license.txt velocity_license.txt xercesImpl_license.txt);
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy Dept_Check
#
chdir("$src/Dept_Check");
print "Copy Dept_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("so_dept_check.config", "$dest/conf/so_dept_check.config") ||
    die "Failed to copy so_dept_check.config to $dest/conf/so_dept_check.config\n";

#
# Copy EPUB_Validate
#
chdir("$src/EPUB_Validate");
print "Copy EPUB_Validate files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.jar>) {
    copy("$file", "$dest/bin/epubcheck/$file") ||
        die "Failed to copy $file to $dest/bin/epubcheck/$file\n";
}
copy("lib.zip", "$dest/bin/epubcheck/lib.zip") ||
    die "Failed to copy lib.zip to $dest/bin/epubcheck/lib.zip\n";
chdir("$dest/bin/epubcheck/");
$zip_file = Archive::Zip->new("lib.zip");
$zip_file->extractTree();
unlink("lib.zip");
chdir("$src/EPUB_Validate/Docs");
@files = qw(epubcheck_license.txt);
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy Feed_Validate
#
chdir("$src/Feed_Validate");
print "Copy Feed_Validate files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("feedvalidator.py", "$dest/bin/feedvalidator.py") ||
    die "Failed to copy feedvalidator.py to $dest/bin/feedvalidator.py\n";
copy("feedvalidator.zip", "$dest/bin/feedvalidator.zip") ||
    die "Failed to copy feedvalidator.zip to $dest/bin/feedvalidator.zip\n";
chdir("$dest/bin");
$zip_file = Archive::Zip->new("feedvalidator.zip");
$zip_file->extractTree();
unlink("feedvalidator.zip");
chdir("$src/Feed_Validate/Docs");
copy("feedvalidator_license.txt", "$dest/documents/licenses/feedvalidator_license.txt") ||
    die "Failed to copy feedvalidator_license.txt to $dest/documents/licenses/feedvalidator_license.txt\n";

#
# Copy HTML_Validate
#
chdir("$src/HTML_Validate");
print "Copy HTML_Validate files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.txt>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
copy("vnu.jar", "$dest/lib/vnu.jar") ||
    die "Failed to copy vnu.jar to $dest/lib/vnu.jar\n";
chdir("$src/HTML_Validate/Docs");
@files = ("vnu_License.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}
chdir("$src/HTML_Validate");
if ( $platform eq "Linux" ) {
    # Copy wdg to dest/bin for Linux platforms
    copy("wdg-sgml-lib-1.1.3.zip", "$dest/bin/wdg-sgml-lib-1.1.3.zip") ||
        die "Failed to copy wdg-sgml-lib-1.1.3.zip to $dest/bin/wdg-sgml-lib-1.1.3.zip\n";
    chdir("$dest/bin");
}
else {
    # Copy wdg to dest/ for Windows platforms
    copy("wdg-sgml-lib-1.1.3.zip", "$dest/wdg-sgml-lib-1.1.3.zip") ||
        die "Failed to copy wdg-sgml-lib-1.1.3.zip to $dest/wdg-sgml-lib-1.1.3.zip\n";
    chdir("$dest");
}
$zip_file = Archive::Zip->new("wdg-sgml-lib-1.1.3.zip");
$zip_file->extractTree();

chdir("$src/HTML_Validate/Docs");
copy("validate_README.txt", "$dest/documents/licenses/validate_README.txt") ||
    die "Failed to copy validate_README.txt to $dest/documents/licenses/validate_README.txt\n";

#
# Copy platform specific files
#
chdir("$src/HTML_Validate");
if ( $platform eq "Windows" ) {
    chdir("$src/HTML_Validate/Windows");
    copy("win_validate.pl", "$dest/bin/win_validate.pl") ||
        die "Failed to copy win_validate.pl to $dest/bin/win_validate.pl\n";
    copy("sp1_3_4.zip", "$dest/nsgmls/sp1_3_4.zip") ||
        die "Failed to copy sp1_3_4.zip to $dest/nsgmls/sp1_3_4.zip\n";
    chdir("$dest/nsgmls");
    $zip_file = Archive::Zip->new("sp1_3_4.zip");
    $zip_file->extractTree();
    unlink("sp1_3_4.zip");
}
elsif ( $platform eq "Linux" ) {
    chdir("$src/HTML_Validate/Linux");
    copy("validate", "$dest/bin/validate") ||
        die "Failed to copy validate to $dest/bin/validate\n";
    chdir("Linux");
    copy("lq-nsgmls", "$dest/bin/lq-nsgmls") ||
        die "Failed to copy lq-nsgmls to $dest/bin/lq-nsgmls\n";
    copy("lq-nsgmls", "$dest/bin/lq-nsgmls_en") ||
        die "Failed to copy lq-nsgmls to $dest/bin/lq-nsgmls_en\n";
    copy("lq-nsgmls", "$dest/bin/lq-nsgmls_fr") ||
        die "Failed to copy lq-nsgmls to $dest/bin/lq-nsgmls_fr\n";
}

#
# Copy Interop_Check
#
chdir("$src/Interop_Check");
print "Copy Interop_Check files\n";
for $file (<*.config>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("schema_org.json", "$dest/conf/schema_org.json") ||
    die "Failed to copy schema_org.json to $dest/conf/schema_org.json\n";

#
# Copy JavaScript_Check
#
chdir("$src/JavaScript_Check");
print "Copy JavaScript_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.txt>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}

#
# Copy platform specific files
#
if ( $platform eq "Windows" ) {
    chdir("$src/JavaScript_Check/Windows");
    copy("jsl.exe", "$dest/bin/jsl.exe") ||
        die "Failed to copy jsl.exe to $dest/bin/jsl.exe\n";
}
elsif ( $platform eq "Linux" ) {
    chdir("$src/JavaScript_Check/Linux");
    copy("jsl", "$dest/bin/jsl") ||
        die "Failed to copy jsl to $dest/bin/jsl\n";
}

#
# Copy Link_Check
#
chdir("$src/Link_Check");
print "Copy Link_Check files\n";
copy("so_link_check.config", "$dest/conf/so_link_check.config") ||
    die "Failed to copy so_link_check.config to $dest/conf/so_link_check.config\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}

#
# Copy MARC_Validate
#
chdir("$src/MARC_Validate");
print "Copy MARC_Validate files\n";
for $file (<*.jar>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
chdir("$src/MARC_Validate/Docs");
@files = qw(metadata_qa_marc_license.txt);
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy Metadata_Check
#
chdir("$src/Metadata_Check");
print "Copy Metadata_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("so_metadata_check.config", "$dest/conf/so_metadata_check.config") ||
    die "Failed to copy so_metadata_check.config to $dest/conf/so_metadata_check.config\n";
@files = qw(compressed_goc_core_subject_thesaurus_eng.txt
            compressed_goc_core_subject_thesaurus_fra.txt);
for $file (@files) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}

#
# Copy Mobile_Check
#
chdir("$src/Mobile_Check");
print "Copy Mobile_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
@files = qw(mobile_check_config.txt
            mobile_testcase_url.config);
for $file (@files) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
chdir("$src/Mobile_Check/Docs");
@files = ("jpegoptim_copyright.txt", "optipng_license.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy platform specific files
#
if ( $platform eq "Windows" ) {
    chdir("$src/Mobile_Check/Windows");
    copy("jpegoptim.exe", "$dest/bin/jpegoptim.exe") ||
        die "Failed to copy jpegoptim.exe to $dest/bin/jpegoptim.exe\n";
    copy("optipng.exe", "$dest/bin/optipng.exe") ||
        die "Failed to copy optipng.exe to $dest/bin/optipng.exe\n";
}
elsif ( $platform eq "Linux" ) {
    chdir("$src/Mobile_Check/Linux");
    copy("jpegoptim", "$dest/bin/jpegoptim") ||
        die "Failed to copy jpegoptim to $dest/bin/jpegoptim\n";
    copy("optipng", "$dest/bin/optipng") ||
        die "Failed to copy optipng to $dest/bin/optipng\n";
}

#
# Copy Open_Data_Check
#
chdir("$src/Open_Data");
print "Copy Open_Data files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
$file = "open_data_testcase_url.config";
copy("$file", "$dest/conf/$file") ||
     die "Failed to copy $file to $dest/conf/$file\n";
for $file (<*.txt>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
copy("json_schema_validator.py", "$dest/bin/json_schema_validator.py") ||
     die "Failed to copy json_schema_validator.py to $dest/bin/json_schema_validator.py\n";
copy("csv-validator.zip", "$dest/bin/csv-validator.zip") ||
     die "Failed to copy csv-validator.zip to $dest/bin/csv-validator.zip\n";
chdir("$dest/bin");
$zip_file = Archive::Zip->new("csv-validator.zip");
$zip_file->extractTree();
unlink("csv-validator.zip");
#
# Copy python modules
#
chdir("$src/Open_Data");
@files = qw(functools32-3.2.3-2.zip
            jsonschema-2.6.0.zip
            setuptools-29.0.1.zip
            vcversioner-2.16.0.0.zip);
for $file (@files) {
    copy("$file", "$dest/python/$file") ||
         die "Failed to copy $file to $dest/python/$file\n";
}
chdir("$src/Open_Data/Docs");
@files = ("csv-validator_license.txt", "csvlint_license.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}
#
# Copy platform specific files
#
if ( $platform eq "Windows" ) {
    chdir("$src/Open_Data/Windows");
    copy("csvlint.exe", "$dest/bin/csvlint.exe") ||
        die "Failed to copy csvlint.exe to $dest/bin/csvlint.exe\n";
}
elsif ( $platform eq "Linux" ) {
    chdir("$src/Open_Data/Linux");
    copy("csvlint", "$dest/bin/csvlint") ||
        die "Failed to copy csvlint to $dest/bin/csvlint\n";
}

#
# Copy PDF_Check
#
chdir("$src/PDF_Check");
print "Copy PDF_Check files\n";
for $file (<*.config>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
chdir("$src/PDF_Check/Windows");
for $file (<*.exe>) {
    copy("$file", "$dest/bin/$file") ||
        die "Failed to copy $file to $dest/bin/$file\n";
}
chdir("$src/PDF_Check/Docs");
@files = ("xpdf_README.txt", "xpdf_COPYING.txt", "xpdf_doc.zip");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

chdir("$dest/documents/licenses/");
$zip_file = Archive::Zip->new("xpdf_doc.zip");
$zip_file->extractTree();

#
# Copy platform specific files
#
if ( $platform eq "Windows" ) {
    chdir("$src/PDF_Check/Windows");
    for $file (<*.exe>) {
        copy("$file", "$dest/bin/$file") ||
            die "Failed to copy $file to $dest/bin/$file\n";
    }
}
elsif ( $platform eq "Linux" ) {
    chdir("$src/PDF_Check/Linux");
    for $file (<pdf*>) {
        copy("$file", "$dest/bin/$file") ||
            die "Failed to copy $file to $dest/bin/$file\n";
    }
}

#
# Copy Robots_Check
#
chdir("$src/Robots_Check");
print "Copy Robots_Check files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}

#
# Copy TQA_Check
#
chdir("$src/TQA_Check");
print "Copy TQA_Check files\n";
@files = qw(so_html_features.config so_tqa_check.config tqa_testcase_url.config);
for $file (@files) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.rdf>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
chdir("$src/TQA_Check/CSS");
for $file (<*.pm>) {
    copy("$file", "$dest/lib/CSS/$file") ||
        die "Failed to copy $file to $dest/lib/CSS/$file\n";
}
chdir("$src/TQA_Check/CSS/Adaptor");
for $file (<*.pm>) {
    copy("$file", "$dest/lib/CSS/Adaptor/$file") ||
        die "Failed to copy $file to $dest/lib/CSS/Adaptor/$file\n";
}
chdir("$src/TQA_Check/CSS/Parse");
for $file (<*.pm>) {
    copy("$file", "$dest/lib/CSS/Parse/$file") ||
        die "Failed to copy $file to $dest/lib/CSS/Parse/$file\n";
}
chdir("$src/TQA_Check/Text");
for $file (<*.pm>) {
    copy("$file", "$dest/lib/Text/$file") ||
        die "Failed to copy $file to $dest/lib/Text/$file\n";
}
chdir("$src/TQA_Check");
copy("Image.pm.zip", "$dest/lib/Image.pm.zip") ||
    die "Failed to copy Image.pm.zip to $dest/lib/Image.pm.zip\n";
copy("ExifTool.zip", "$dest/lib/ExifTool.zip") ||
    die "Failed to copy ExifTool.zip to $dest/lib/ExifTool.zip\n";
copy("pdfchecker.zip", "$dest/bin/pdfchecker.zip") ||
    die "Failed to copy pdfchecker.zip to $dest/bin/pdfchecker.zip\n";
chdir("$dest/lib");
$zip_file = Archive::Zip->new("Image.pm.zip");
$zip_file->extractTree();
$zip_file = Archive::Zip->new("ExifTool.zip");
$zip_file->extractTree();
chdir("$dest/bin");
$zip_file = Archive::Zip->new("pdfchecker.zip");
$zip_file->extractTree();
unlink("pdfchecker.zip");
chdir("$src/TQA_Check/Docs");
@files = ("CSS_README.txt", "CSV_README.txt", "pdfchecker_License.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy Validator_GUI
#
chdir("$src/Validator_GUI");
print "Copy Validator_GUI files\n";
@files = qw(validator_xml.pm wpss_strings.pm);
for $file (@files) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
copy("validator_gui.pm", "$dest/lib/GUI/validator_gui.pm") ||
    die "Failed to copy validator_gui.pm to $dest/lib/GUI/validator_gui.pm\n";
@files = qw(install.pl install_deque_axe.pl install_pa11y.pl install_puppeteer.pl
            open_data_tool.pl uninstall.pl version.txt wpss_tool.pl
            wpss_tool_en.pl wpss_tool_fr.pl
            Win32-GUI-1.14.zip Win32_IE.zip);
for $file (@files) {
    copy("$file", "$dest/$file") ||
        die "Failed to copy $file to $dest/$file\n";
}
for $file (<*.config>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
chdir("$dest");
$zip_file = Archive::Zip->new("Win32-GUI-1.14.zip");
$zip_file->extractTree();
unlink("Win32-GUI-1.14.zip");
chdir("Win32-GUI-1.14");
rename("Win32-GUI_Constants","Win32-GUI-Constants");
chdir("$dest");
$zip_file = Archive::Zip->new("Win32_IE.zip");
$zip_file->extractTree();
unlink("Win32_IE.zip");
chdir("$src/Validator_GUI/Docs");
@files = ("Win32-GUI_README.txt", "Win32-IE_README.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}
chdir("$src/Validator_GUI");
@files = ("Web-WPSS Standalone Validation Tool Testcases.doc",
          "Web-WPSS Standalone Validation Tool Testcases Fra.doc",
          "Web-PWGSC WPSS Validation Tool User Guide.docx",
          "Web-WPSS Open Data Tool User Guide.docx");
for $file (@files) {
    copy("$file", "$dest/documents/$file") ||
        die "Failed to copy $file to $dest/documents/$file\n";
}
copy("WPSS Validation Tool Fra.doc", "$dest/documents/User_Guide-fra.doc") ||
    die "Failed to copy WPSS Validation Tool Fra.doc to $dest/documents/User_Guide-fra.doc\n";
copy("Release_Notes.txt", "$dest/documents/Release_Notes.txt") ||
    die "Failed to copy Release_Notes.txt to $dest/documents/Release_Notes.txt\n";
chdir("$src");
@files = ("License-en.txt", "Licence-fr.txt");
for $file (@files) {
    copy("$file", "$dest/documents/$file") ||
        die "Failed to copy $file to $dest/documents/$file\n";
}

#
# Copy Validator_CLI
#
chdir("$src/Validator_CLI");
print "Copy Validator_CLI files\n";
@files = qw(validator_gui.pm);
for $file (@files) {
    copy("$file", "$dest/lib/CLI/$file") ||
        die "Failed to copy $file to $dest/lib/CLI/$file\n";
}
copy("wpss_tool_cli.pl", "$dest/wpss_tool_cli.pl") ||
    die "Failed to copy wpss_tool_cli.pl to $dest/wpss_tool_cli.pl\n";

#
# Copy platform specific files
#
if ( $platform eq "Linux" ) {
    chdir("Win32");
    copy("TieRegistry.pm", "$dest/Win32/TieRegistry.pm") ||
        die "Failed to copy TieRegistry.pm to $dest/Win32/TieRegistry.pm\n";
}

#
# Copy XML_Validate
#
chdir("$src/XML_Validate");
print "Copy XML_Validate files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.jar>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
chdir("$src/XML_Validate/Docs");
@files = ("ttv_License.txt", "xsdv_license.txt");
for $file (@files) {
    copy("$file", "$dest/documents/licenses/$file") ||
        die "Failed to copy $file to $dest/documents/licenses/$file\n";
}

#
# Copy Web_Analytics
#
chdir("$src/Web_Analytics");
print "Copy Web_Analytics files\n";
for $file (<*.pm>) {
    copy("$file", "$dest/lib/$file") ||
        die "Failed to copy $file to $dest/lib/$file\n";
}
for $file (<*.config>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}
for $file (<*.txt>) {
    copy("$file", "$dest/conf/$file") ||
        die "Failed to copy $file to $dest/conf/$file\n";
}



