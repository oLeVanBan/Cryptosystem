class DocumentsController < ApplicationController
  require 'open-uri'

  def index
    @document = Document.new
  end

  def create
    # http://www.govap.hochiminhcity.gov.vn/chuyende/lists/posts/post.aspx?ItemID=651
    import_database and return if params[:link]
    cipher_encryptor = CipherEncryptor.new(nil, document_params[:content], params[:type])
    cipher_encryptor.encode
    cipher = Cipher.create content: cipher_encryptor.pwd,
      max_length: cipher_encryptor.max_length
    @document = Document.new document_params.merge encryption_type: params[:type]
    @document.cipher = cipher
    @document.content = cipher_encryptor.document
    if @document.save
      redirect_to root_path(notice: true)
    else
      redirect_to root_path(notice: false)
    end
  end

  def show
    @document = Document.find params[:id]
    @cipher_encryptor = CipherEncryptor.new(@document.cipher.content.split(","),
      @document.content, @document.encryption_type)
    @cipher_encryptor.decode
  end

  def destroy
    Document.find(params[:id]).destroy
    redirect_to documents_path
  end

  private
  def document_params
    params.require(:document).permit Document::DEFAULT_ATTRIBUTES
  end

  def import_database
    start_id, end_id, type = [params[:start_id], params[:end_id], params[:type]]
      .map &:to_i
    diff = end_id - start_id + 1
    model = CipherEncryptor::MODELS[params[:type].to_i].constantize
    count = model.count
    keys = model.pluck :key
    if diff <= 0
      doc = Nokogiri::HTML(open(params[:link])).text.squeeze.strip.gsub /\r\n|\r|\n/, ""
      model.import_databases keys, doc
    else
      diff.times do |i|
        id = start_id + i
        doc = Nokogiri::HTML(open(params[:link] + id.to_s)).text.squeeze.strip.gsub /\r\n|\r|\n/, ""
        model.import_databases keys, doc
      end
    end
    redirect_to root_path(count: model.count - count)
  rescue
    redirect_to root_path
  end
end
