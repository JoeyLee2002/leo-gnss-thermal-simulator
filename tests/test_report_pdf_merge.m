function tests=test_report_pdf_merge
tests=functiontests(localfunctions);
end

function testRepeatedMergeAndPageOrder(testCase)
folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder,'s'));
pages=cell(1,3);
for k=1:3
    doc=javaObject('org.apache.pdfbox.pdmodel.PDDocument');
    page=javaObject('org.apache.pdfbox.pdmodel.PDPage');
    box=javaObject('org.apache.pdfbox.pdmodel.common.PDRectangle',single(200+k),single(300+k));
    page.setMediaBox(box); doc.addPage(page);
    pages{k}=fullfile(folder,sprintf('%d.pdf',k)); doc.save(pages{k}); doc.close();
end
for run=1:20
    destination=fullfile(folder,sprintf('merged_%d.pdf',run));
    leotherm.mergeReportPdfPages(pages,destination);
    doc=javaMethod('load','org.apache.pdfbox.pdmodel.PDDocument',javaObject('java.io.File',destination));
    verifyEqual(testCase,double(doc.getNumberOfPages()),3);
    for k=1:3, verifyEqual(testCase,double(doc.getPage(k-1).getMediaBox().getWidth()),200+k); end
    doc.close();
end
end

function testExistingAndMissingFilesAreRejected(testCase)
folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder,'s'));
file=fullfile(folder,'keep.pdf'); fid=fopen(file,'w'); fprintf(fid,'original'); fclose(fid);
verifyError(testCase,@()leotherm.mergeReportPdfPages({file},file),'leotherm:ReportExport');
verifyEqual(testCase,fileread(file),'original');
verifyError(testCase,@()leotherm.mergeReportPdfPages({fullfile(folder,'missing.pdf')},fullfile(folder,'new.pdf')), ...
    'leotherm:ReportExport');
verifyFalse(testCase,isfile(fullfile(folder,'new.pdf')));
end
