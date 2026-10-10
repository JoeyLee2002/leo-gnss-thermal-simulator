function mergeReportPdfPages(pages, destination)
%MERGEREPORTPDFPAGES Assemble generated pages with Runtime's Apache PDFBox.
% Publish only after reopening and verifying the assembled page count.
if isempty(pages) || isfile(destination)
    error('leotherm:ReportExport','Supply generated PDF pages and a new destination.');
end
for k=1:numel(pages)
    if ~isfile(pages{k}), error('leotherm:ReportExport','Missing PDF page: %s',pages{k}); end
end
scratch=[tempname(fileparts(destination)) '.pdf'];
cleanup=onCleanup(@() removeScratch(scratch));
% PDFBox 2.x ships with supported MATLAB/Runtime R2021b. No Python or Office.
merger=javaObject('org.apache.pdfbox.multipdf.PDFMergerUtility');
for k=1:numel(pages), merger.addSource(javaObject('java.io.File',pages{k})); end
merger.setDestinationFileName(scratch);
memory=javaMethod('setupTempFileOnly','org.apache.pdfbox.io.MemoryUsageSetting');
merger.mergeDocuments(memory);
document=javaMethod('load','org.apache.pdfbox.pdmodel.PDDocument',javaObject('java.io.File',scratch));
closeDocument=onCleanup(@() document.close());
if document.getNumberOfPages()~=numel(pages)
    error('leotherm:ReportExport','Assembled PDF page count does not match generated pages.');
end
clear closeDocument
[ok,message]=movefile(scratch,destination);
if ~ok, error('leotherm:ReportExport','Cannot publish report: %s',message); end
end

function removeScratch(path)
if isfile(path), delete(path); end
end
