package PDF::Extract;  

=head1 NAME

PDF::Extract - Extracting sub PDF documents from a multipage PDF document

=head1 SYNOPSIS

 use PDF::Pages;
 $pdf=new PDF::Pages;
 $pdf->servePDFExtract( PDFDoc=>"c:/Docs/my.pdf", PDFPages=>"1-3 31-36" );

or 

 use PDF::Pages;
 $pdf = new PDF::Pages( PDFDoc=>'C:/my.pdf' );
 $pdf->getPDFExtract( PDFPages=>@PDFPages );
 print "Content-Type text/plain\n\n<pre>",  $pdf->getPDFExtractOut;
 print $pdf->getPDFExtractError;

=head1 DESCRIPTION

PDF Extract is a group of methods that allow the user to quickly grab pages
as a new PDF document from a pre-existing PDF document.

 With PDF::Extract a new PDF document can be:-

=over 4

=item * 

assigned to a scalar variable with getPDFExtract.

=item * 

saved to disk with savePDFExtract.

=item * 

printed to STDOUT as a PDF web document with servePDFExtract.

=item * 

cached and served for a faster PDF web document service with fastServePDFExtract.

=back

These four main methods can be called with or without arguments. The methods 
will not work unless they know the location of the original PDF document and the 
pages to extract. There are no default values.

=cut

use strict;
use warnings;
use vars qw($VERSION);
$VERSION = '1.01';

my $PDFExtractError;                    # A discription and location of an Error in processing PDF Page
my $PDFExtractFound;                  # Number of pages found in document
my $PDFExtractOut;                      # The PDF Pages output if any
my $PDFExtractCachePath;           # The cache path passed to PDFExtract
my $PDFExtractDoc;                     # The location of the source PDF Doc

my ( $pages, $filename, $CatalogPages, $Root, $pdf, $pdfFile, $object, $encryptedPdf, $trailerObject,$fileNumber );
my ( @object, @PDFPages, @obj, @instnum, @pages ); 
my ( %getPages, %pageObject );

# ----------------------------------------------------------- The Public Methods --------------------------------------------------------------

=head1 METHODS

=head2 new PDF::Extract

Creates a new Extract object with empty state information ready for processing
data both input and output. New can be called with a hash array argument.

 new PDF::Extract( PDFDoc=>"c:/Docs/my.pdf", PDFPages=>"1-3 31-36" )

This will cause a new PDF document to be generated unless there is an error.
Extract->new() simply calls getPDFExtract() if there is an argument.

=cut

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->getPDFExtract( @_) if @_;
    return $self;
}

=head2 getPDFExtract

This method is the main workhorse of the package. It does all the PDF processing
and sets PDFExtractError if its unable to create a new PDF document. It requires
PDFDoc and PDFPages to be set either in this call of before to function. 
It outputs a PDF document as a string or an empty string if there is an error.

To create an array of PDF documents, each consisting of a single page, 
from a multi page PDF document.

  $pdf = new PDF::Pages( PDFDoc=>'C:/my.pdf' );
  while ( $pdf[$i]=$pdf->getPDFExtract( PDFPages=>++$i ) );

The lowest valid page number for PDFPages is 1. A value of 0 will produce no 
output and raise an error. An error will be raised if the PDFPages value does
not correspond to any pages.

=cut

sub getPDFExtract{                   
	&getEnv(@_);    
	&getDoc;
    $PDFExtractOut;
}

=head2  savePDFExtract

This method saves its output to what ever PDFExtractCache is set to. 
The new file name will be an amalgam of the original filename, the page numbers of the extracted pages separated with an underscore "_" and the .pdf file type suffix.
 
  $pdf = new PDF::Pages;
  $pdf->savePDFExtract(PDFPage=>"1 3-5", PDFDoc=>'C:/my.pdf', PDFExtractCache=>"C:/myCache" );

The saved PDF location and file name will be "C:/myCache/my_1_3_4_5.pdf".

=cut

sub savePDFExtract{
	&getEnv(@_);    
	&getDoc;
	&savePdfDoc;
	$PDFExtractError ? "" : 1;
}

=head2  servePDFExtract

This method serves its output to STDOUT with the correct header for a PDF document served on the web. 
The served file's name will be an amalgam of the original filename, the page numbers of the extracted pages separated with an underscore "_" and the .pdf file type suffix.
If there is an error then an error page will be served.
 
  $pdf = PDF::Pages->new;
  $pdf->servePDFExtract( PDFDoc=>'C:/my.pdf', PDFPage=>1);

The file name of the served file will be "my_1.pdf".

=cut

sub servePDFExtract{
    &getEnv(@_);    
    &getDoc;
    &uploadPDFDoc;
	$PDFExtractError ? "" : 1;
}

=head2  fastServePDFExtract

This method serves its output to STDOUT with the correct header for a PDF document served on the web. 
The served file's name will be an amalgam of the original filename, the page numbers of the extracted pages separated with an underscore "_" and the .pdf file type suffix.
This method also checks to see if the PDF document requested is in the cache folder, as set with PDFExtractCache.
If it exists then this file is served instead of processing a new PDF document.
If there is an error then an error page will be served.
 
  $pdf = new PDF::Pages(PDFExtractCache=>"C:/myCache" );
  $pdf->fastServePDFExtract( PDFDoc=>'C:/my.pdf', PDFPage=>1);

The file name of the served file will be "my_1.pdf".

=cut

sub fastServePDFExtract{
	&getEnv(@_);    
	&redirect if -e "$PDFExtractCachePath/$filename.pdf";
	&getDoc;
	&savePdfDoc;
	&redirect;
	&uploadPDFDoc;
	$PDFExtractError ? "" : 1;
}

=head2 getPDFExtractError

 $pdf->getPDFExtractError;

This method returns an error message if there is one.
An error is set if the output from any other method is an empty string.

The error message is comprised of a short description, a file and the line number 
of where the error was detected. 

=cut

sub getPDFExtractError {   # $PDFExtractError is set when no output
    $PDFExtractError;
}

=head2 getPDFExtractDoc

 $pdf->getPDFExtractDoc;

This method returns the last original PDF document accessed by getPDFExtract, savePDFExtract, servePDFExtract and fastServePDFExtract.
getPDFExtractDoc will return an empty string if there was an error.

=cut

sub getPDFExtractDoc {
    $PDFExtractDoc;
}

=head2 getPDFExtractOut

 $pdf->getPDFExtractOut;

This method returns the last PDF document processed by getPDFExtract, savePDFExtract, servePDFExtract and fastServePDFExtract.
getPDFExtractOut will return an empty string if there was an error.

=cut

sub getPDFExtractOut {
    $PDFExtractOut;
}

=head2 getPDFExtractCachePath

 $pdf->getPDFExtractCachePath;

This method returns the path to the PDF document cache. This value is required by savePDFExtract and fastServePDFExtract method calls.
getPDFExtractCachePath will return an empty string if there was an error in setting the value.

=cut

sub getPDFExtractCachePath {
    $PDFExtractCachePath;
}

=head2 setPDFExtractCachePath

 $pdf->setPDFExtractCachePath("C:\myCache");

This method returns the path to the PDF document cache. This value is required by savePDFExtract and fastServePDFExtract method calls.
setPDFExtractCachePath will return an empty string if there was an error in setting the value.

=cut

sub setPDFExtractCachePath {
    my (undef,  $var)=@_;
    &Env( "PDFExtractCache", $var ) if $var;
    $PDFExtractCachePath;
}

=head2 getPDFExtractFound

 $pdf->getPDFExtractFound;

This method returns a string representing the pages that were selected and found within the original PDF document.
getPDFExtractFound will return an empty string if there was an error in setting the value.

=cut

sub getPDFExtractFound {
    $PDFExtractFound;
}

# ----------------------------------------------------------- The Private Functions --------------------------------------------------------------

sub getEnv {
    my (undef,  %PDF)=@_;
    my $requestedPages=0;
    $PDFExtractError="";
    # Initialize variables for reuse
    if ($PDF{ "PDFDoc" } ) {
    
        $PDFExtractFound=$PDFExtractOut="";
        $pdfFile=$filename=$CatalogPages=$Root=$object=$encryptedPdf=$trailerObject="";
        @object=@obj=@pages=(); 
        %pageObject=();
        
        $PDFExtractDoc=$PDF{ "PDFDoc" };
        $filename=$1 if  $PDFExtractDoc=~/([^\\\/]+)\.pdf$/i;
        return  &error(" PDF document \"$filename\" not found",__FILE__,__LINE__) unless -f $PDFExtractDoc;
	    $\="\r";
	    return &error( "Can't open $PDFExtractDoc to read\n",__FILE__,__LINE__) unless  open FILE, $PDFExtractDoc;
		binmode FILE;
		$pdfFile = join('', <FILE>);
		close FILE;
		
    } 
    if ($PDF{ "PDFPages" } ) {
    
        $PDFExtractFound=$PDFExtractOut="";
        $CatalogPages=$Root=$object=$encryptedPdf=$trailerObject="";
        @object=@obj=@pages=(); 
        %getPages=%pageObject=();

        @PDFPages=$PDF{ "PDFPages" };
		$pages=join " ", @PDFPages; 
		my $pageError=$pages;
		$pages=~s/ +/,/g;
		$pages=~s/\-/../g;
		$pages=~s/[^\d,\.]//g;                  # allow only numbers to be processed
		foreach my $page ( eval $pages ) {
		    next unless int $page;
	        $getPages{int $page}=1;
	        $requestedPages++;
	    }
	    return &error("Can't get PDF Pages. No page numbers were set with '$pages' ",__FILE__,__LINE__) unless $requestedPages;
	    $pages="";
	    foreach my $page ( sort  keys %getPages) { 
	        $fileNumber.="_$page";
	        $pages.="$page, ";
	    }
	    $pages=~s/, $//;
	 }
	 if ($PDF{ "PDFExtractCache"} ) {
        $PDFExtractCachePath=dir($PDF{ "PDFExtractCache"});
	 }
}

sub dir {
	my($path,$dir,@folders)=@_;
	$path=~s/\\/\//g;
	(@folders)=split "/", $path;
	foreach my $folder (@folders) {
		$dir.= $folder=~/:/ ? $folder : "/$folder";
		next if $folder=~/:/;
		mkdir $dir, 0x777 unless -d $dir;
		#   print "$dir\n";
	}
	$path=~s/\//\\/g;
	return &error("This Cache/Save path \"$path\" can't be created",__FILE__,__LINE__) 
	    unless -d $path;
	$path;
}

sub redirect {
	exit print "Content-Type: text/html\n\n<META HTTP-EQUIV='refresh' content='0;url=$filename.pdf'>";
}

sub getDoc {
    return if $PDFExtractOut;
	return &error("There is no pdf document to extract pages from",__FILE__,__LINE__) unless $pdfFile;   
	&getRoot;
	&getPages($CatalogPages,0);
	return &error("There are no pages in $filename.pdf that match  '$pages' ",__FILE__,__LINE__) 
	    unless $PDFExtractFound;
	&getObj($Root,0);
	&makePdfDoc;
}

sub savePdfDoc {
	return "" if $PDFExtractError;
	return &error("Can't open $PDFExtractCachePath/$filename$fileNumber.pdf\n",__FILE__,__LINE__) 
	    unless open FILE, ">$PDFExtractCachePath/$filename$fileNumber.pdf";
	binmode FILE;
	print FILE $PDFExtractOut;
	close FILE;
}	

sub uploadPDFDoc {
    return &servError("") if $PDFExtractError;
    my $len=length $PDFExtractOut;
    return &servError("PDF output is null, No output",__FILE__,__LINE__) unless $len;
    print <<EOF;
Content-Disposition: inline; filename=$filename$fileNumber.pdf
Content-Length: $len
Content-Type: application/pdf

$PDFExtractOut
EOF
}

#------------------------------------ support  Routines --------------------------------------------

sub servError {
	my ($error,$file,$line)=@_;
	&error($error,$file,$line) if $error;
	print <<EOF;
	Content-Type: text/html
	
	<font color=red><h2>There is system problem in processing your PDF Pages request</h2></font>
	<pre>ERROR: $PDFExtractError </pre>
EOF
	""
}

sub error {
	my ($error,$file,$line)=@_;
	$PDFExtractError.="$error\nat $file line $line\n";
	""
}

#------------------------------------ PDF Page Routines --------------------------------------------
sub getRoot {
	return "" if $PDFExtractError;
	return  if $Root;
	$pdf=$pdfFile;
    my $val=$1 if $pdf=~/(trailer\s+<<\s+.*?>>\s+)/s;
    $Root=int $1 if $val=~/\/Root (\d+) 0 R/s;    
    $val=~s/\/Size \d+/\/Size __Size__/s;   # Size will change so put a place holder for new size
    $val=~s/\/Prev.*?\r//s;                      # delete Prev reference if its there
    &getObj($1, $2 ) if $val=~/\/Info (\d+) (\d+) R/s;
    &getObj( $encryptedPdf=$1, $2 ) if $val=~/\/Encrypt (\d+) (\d+) R/s;
    $trailerObject=$val;
    $val=$1 if $pdf=~/($Root 0 obj.*?endobj\s+)/;
    $CatalogPages=int $1 if $val=~/\/Pages (\d+) 0 R\s+/s;   
    $val="$Root 0 obj\r<< \r/Type /Catalog \r/Pages $CatalogPages 0 R \r>> \rendobj\r";
    $pdf=~s/($Root 0 obj.*?endobj\s+)/$val/s; 
}

sub getObj {
	return "" if $PDFExtractError;
    my($obj,$instnum)=@_;
    unless ($obj[$obj] ) {
         if ($pdf=~/\s($obj $instnum obj.*?endobj\s)/s ) {
            $object = $1;
#	        return "" if $object=~/\/GoToR/; # Don't want these link objects
            $obj[$obj]++;
	        $object[$obj]=$object;
            $instnum[$obj]=$instnum;
            
	        $object[$obj]=~s/(\/Dest \[ )(\d+)( \d.*?\r)/&uri($1,$2,$3)/es; # Convert page dest to uri if not present
	        $object[$obj]=~s/(\d+) (\d+) R/&getObj($1, $2 )/ges;
#	        $object[$obj]=~s/(\/Dest \[ \d+)==/$1 0/s; # Don't follow this path
	        $object[$obj]=~s/\/Annots \[\s+\]\s+//s; # Delete empty Annots array
	    } else {
	        $PDFExtractError.="Can't find object $obj $instnum obj\n$pdf";
	    }
    }
    "$obj 0 R";
}

sub uri {
    my($dest,$obj,$param)=@_;
    return "$dest$obj$param" if $getPages{ $pageObject{$obj} }; # page is in document    
	#return "/A << /S /URI /URI ($web?PDFDoc%26$PDFExtractDoc&PDFExtract%26$pageObject{$obj})>> \r"
	#    unless $encryptedPdf;
	"";
}

sub getPages {
	return "" if $PDFExtractError;
    my($obj, $instnum)=@_;
    my $val=$1 if $pdf=~/($obj $instnum obj.*?endobj\s+)/;
    my $found="";
    my $count=0;
    if ($val=~/\/Kids \[ (.*?)\]/s ) {     
        my $kids=$1;
        $kids=~s/\s+/ /gs;
        foreach my $kid (split " R ", $kids) {      
            my($f,$c)=&getPages(split " ", $kid);
            $found.=$f;
            $count+=$c;
        }
        $pdf=~s/($obj $instnum obj.*?\/Kids \[).*?\]/$1 $found\]/s;
        $pdf=~s/($obj $instnum obj.*?\/Count )\d+/$1$count/s;
        $found="$obj $instnum R " if $found;
    } else {
        $pageObject{$obj}=push @pages, $obj; # create a hash of all pages
	    if ( $getPages{$pageObject{$obj}} ) {
	    
	        $found="$obj $instnum R ";
	        $count=1; 
	        $PDFExtractFound++;
        }
    }
    ($found,$count);
}

sub makePdfDoc {                        
	return "" if $PDFExtractError;
	return &error("$PDFExtractDoc is not a PDF file",__FILE__,__LINE__) 
	    unless $pdf=~s/^(.*?\r)/\r/;
	$PDFExtractOut=$1;
	$PDFExtractOut.=$1 while( $pdf=~s/^\r(\%.*?\r)/\r/); #include comment lines if any
	my $xref="xxxxxxxxxx 65535 f\n";
	my $objCount=1;
	for( ;$objCount<@object;$objCount++) {
	    if ($object[$objCount]) {
	        $xref.=sprintf("%0.10d %0.5d n\n",length $PDFExtractOut, $instnum[$objCount] );
	        $PDFExtractOut.=$object[$objCount];
	    } else {
	        $xref.="xxxxxxxxxx 00001 f\n"; 
	        my $x=sprintf("%0.10d",$objCount);
	        $xref=~s/xxxxxxxxxx/$x/s;
	    }
	}
	return &error("$PDFExtractDoc does not contain objects",__FILE__,__LINE__) 
	    if $objCount==1;
	$xref=~s/xxxxxxxxxx/0000000000/s;
	my $startXref=length $PDFExtractOut;
	$PDFExtractOut.="\rxref\r0 $objCount \r$xref";
	$trailerObject=~s/__Size__/$objCount/s;
	$PDFExtractOut.="$trailerObject\rstartxref\r$startXref\r\%\%EOF\r";
}   

=head1 AUTHOR

Noel Sharrock E<lt>mailto:nsharrok@lgmedia.com.auE<gt>

PDF::Extract's home page http://www.lgmedia.com.au/PDF/Extract.asp

=head1 COPYRIGHT

Copyright (c) 2003 by Noel Sharrock. All rights reserved.

=head1 LICENSE

This package is free software; you can redistribute it and/or modify it under the same terms as Perl itself, i.e., under the terms of the ``Artistic License'' or the ``GNU General Public License''.

The C library at the core of this Perl module can additionally be redistributed and/or modified under the terms of the ``GNU Library General Public License''.

=head1 DISCLAIMER

This package is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the ``GNU General Public License'' for more details.

PDF::Extract - Extracting sub PDF documents from a multipage PDF document

=cut

#------------------------------------------ End PDF Page ------------------------------------------   

1; 
