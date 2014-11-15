require 'spec_helper'

describe Rspreadsheet::Workbook, :focus=>true do
  it 'has correct number of sheets' do
    book = Rspreadsheet::Workbook.new($test_filename)
    book.worksheets_count.should == 1
    book.worksheets[0].should be_nil
    book.worksheets[1].should be_kind_of(Rspreadsheet::Worksheet)
    book.worksheets[2].should be_nil
    book.worksheets[nil].should be_nil
  end
  it 'freshly created has correctly namespaced xmlnode' do
    @xmlnode = Rspreadsheet::Workbook.new.xmlnode
    @xmlnode.namespaces.to_a.size.should >5
    @xmlnode.namespaces.find_by_prefix('office').should_not be_nil
    @xmlnode.namespaces.find_by_prefix('table').should_not be_nil
    @xmlnode.namespaces.namespace.prefix.should == 'office'
  end
  it 'can create worksheets, and count them' do
    book = Rspreadsheet::Workbook.new()
    book.worksheets_count.should == 0
    book.create_worksheet
    book.worksheets_count.should == 1
    book.create_worksheet
    book.create_worksheet
    book.worksheets_count.should == 3
  end
  it 'nonemptycells behave correctly' do
    book = Rspreadsheet::Workbook.new()
    book.create_worksheet
    @sheet = book.worksheets[1]
    @sheet.cells(3,3).value = 'data'
    @sheet.cells(5,7).value = 'data'
    @sheet.nonemptycells.collect{|c| c.coordinates}.should =~  [[3,3],[5,7]]
  end

end 