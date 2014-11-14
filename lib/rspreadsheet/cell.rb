require 'andand'
require 'rspreadsheet/xml_tied'

module Rspreadsheet
  
class Cell < XMLTiedItem
  attr_accessor :worksheet, :rowi, :coli
  def xml_repeated_attribute;  'number-columns-repeated' end
  def xml_items_node_name; 'table-cell' end
  def xml_options; {:xml_items_node_name => xml_items_node_name, :xml_repeated_attribute => xml_repeated_attribute} end
  def parent; row end
  def index; @coli end
  def set_index(value); @coli=value end
    
  def initialize(aworksheet,arowi,acoli)
    @worksheet = aworksheet
    @rowi = arowi
    @coli = acoli
  end
  def row; @worksheet.rows(rowi) end
  def coordinates; [rowi,coli] end
  def to_s; value.to_s end

  def value
    gt = guess_cell_type
    if (self.mode == :regular) or (self.mode == :repeated)
      case 
        when gt == nil then nil
        when gt == Float then xmlnode.attributes['value'].to_f
        when gt == String then xmlnode.elements.first.andand.content.to_s
        when gt == Date then Date.strptime(xmlnode.attributes['date-value'].to_s, '%Y-%m-%d')
        when gt == 'percentage' then xmlnode.attributes['value'].to_f
      end
    elsif self.mode == :outbound
      nil
    else
      raise "Unknown cell mode #{self.mode}"
    end
  end
  def value=(avalue)
    detach_if_needed
    if self.mode == :regular
      gt = guess_cell_type(avalue)
      case
        when gt == nil then raise 'This value type is not storable to cell'
        when gt == Float 
          set_type_attribute('float')
          remove_all_value_attributes_and_content(xmlnode)
          Tools.set_ns_attribute(xmlnode,'office','value', avalue.to_s) 
          xmlnode << LibXML::XML::Node.new('p', avalue.to_f.to_s, Tools.get_namespace('text'))
        when gt == String then
          set_type_attribute('string')
          remove_all_value_attributes_and_content(xmlnode)
          xmlnode << LibXML::XML::Node.new('p', avalue.to_s, Tools.get_namespace('text'))
        when gt == Date then 
          set_type_attribute('date')
          remove_all_value_attributes_and_content(xmlnode)
          Tools.set_ns_attribute(xmlnode,'office','date-value', avalue.strftime('%Y-%m-%d'))
          xmlnode << LibXML::XML::Node.new('p', avalue.strftime('%Y-%m-%d'), Tools.get_namespace('text')) 
        when gt == 'percentage'
          set_type_attribute('float')
          remove_all_value_attributes_and_content(xmlnode)
          Tools.set_ns_attribute(xmlnode,'office','value', avalue.to_f.to_s) 
          xmlnode << LibXML::XML::Node.new('p', (avalue.to_f*100).round.to_s+'%', Tools.get_namespace('text'))
      end
    else
      raise "Unknown cell mode #{self.mode}"
    end
  end
  def set_type_attribute(typestring)
    Tools.set_ns_attribute(xmlnode,'office','value-type',typestring)
  end
  def remove_all_value_attributes_and_content(node)
    if att = Tools.get_ns_attribute(node, 'office','value') then att.remove! end
    if att = Tools.get_ns_attribute(node, 'office','date-value') then att.remove! end
    node.content=''
  end
  def relative(rowdiff,coldiff)
    @worksheet.cells(self.rowi+rowdiff, self.coli+coldiff)
  end
  def type
    gct = guess_cell_type
    case 
      when gct == Float  then :float
      when gct == String then :string
      when gct == Date   then :date
      when gct == :percentage then :percentage
      when gct == :unassigned then :unassigned
      when gct == nil then :unknown
      else :unknown
    end
  end
  def guess_cell_type(avalue=nil)
    # try guessing by value
    valueguess = case avalue
      when Numeric then Float
      when Date then Date
      when String,nil then nil
      else nil
    end
    result = valueguess

    if valueguess.nil? # valueguess is most important
      # if not succesfull then try guessing by type from node xml
      typ = xmlnode.nil? ? 'N/A' : xmlnode.attributes['value-type']
      typeguess = case typ
        when nil then nil
        when 'float' then Float
        when 'string' then String
        when 'date' then Date
        when 'percentage' then :percentage
        when 'N/A' then :unassigned
        else 
          if xmlnode.children.size == 0
            nil
          else 
            raise "Unknown type at #{coordinates.to_s} from #{xmlnode.to_s} / children size=#{xmlnode.children.size.to_s} / type=#{xmlnode.attributes['value-type'].to_s}"
          end
      end

      result =
      if !typeguess.nil? # if not certain by value, but have a typeguess
        if !avalue.nil?  # with value we may try converting
          if (typeguess(avalue) rescue false) # if convertible then it is typeguess
            typeguess
          elsif (String(avalue) rescue false) # otherwise try string
            String
          else # if not convertible to anything concious then nil
            nil 
          end
        else             # without value we just beleive typeguess
          typeguess
        end
      else # it not have a typeguess
        if (String(avalue) rescue false) # convertible to String
          String
        else
          nil
        end
      end
    end
    result
  end
end
  
# class Cell
#   def self.empty_cell_node
#     LibXML::XML::Node.new('table-cell',nil, Tools.get_namespace('table'))
#   end
#   def initialize(aparent_row,coli,axmlnode=nil)
#     raise "First parameter should be Row object not #{aparent_row.class}" unless aparent_row.kind_of?(Rspreadsheet::Row)
#     @parent_row = aparent_row
#     if axmlnode.nil?
#       axmlnode = Cell.empty_cell_node
#     end
#     @xmlnode = axmlnode
#     @col = coli
#     # set @mode
#     @mode = case
#       when !@parent_row.used_col_range.include?(coli) then :outbound
#       when Tools.get_ns_attribute_value(@xmlnode, 'table', @@xml_repeated_attribute).to_i>1  then :repeated
#       else:regular
#     end
#   end
#   def xml; self.xmlnode.children.first.andand.inner_xml end
#   def address; Rspreadsheet::Tools.c2a(row,col) end
#   def row; @parent_row.row end
#   def worksheet; @parent_row.worksheet end
#   # use this to find node in cell xml. ex. xmlfind('.//text:a') finds all link nodes
#   def xmlfindall(path)
#     xmlnode.find(path)
#   end
#   def xmlfindfirst(path)
#     xmlfindall(path).first
#   end
#   # based on @xmlnode and optionally value which is about to be assigned, guesses which type the result should be
#   def inspect
#     "#<Rspreadsheet::Cell:Cell\n row:#{row}, col:#{col} address:#{address}\n type: #{guess_cell_type.to_s}, value:#{value}\n mode: #{mode}\n>"
#   end
# end

end












