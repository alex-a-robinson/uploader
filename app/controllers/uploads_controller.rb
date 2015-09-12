require 'digest/md5'

class UploadsController < ApplicationController
  http_basic_authenticate_with name: "name", password: "password", except:[:show]

  def new
  end

  def index
    destroy_expired
    @uploads = Upload.all
  end

  def create
    @uploads = params[:upload][:uploaded_file]
    for @uploaded in @uploads do
      @identifier = generate_identifier

      # Calculate file hash
      # TODO: Do this chunkwise to save memory for large files
      @filehash = Digest::MD5.hexdigest(@uploaded.read);
      @uploaded.rewind
    
      @uploads_with_same_hash = Upload.where('filehash = ?', @filehash).first
      if @uploads_with_same_hash
        render 'new'
        return
      end

      # Write the file to the uploads directory
      File.open(Rails.root.join('public', 'uploads', @identifier), 'wb') do |file|
        file.write(@uploaded.read)
      end

      # Calculate file size
      @filesize = File.size(Rails.root.join('public', 'uploads', @identifier))

      # Save the files data
      @upload = Upload.new({
        'identifier' => @identifier,
        'owner' => request.remote_ip,
        'expires' => params[:upload].has_key?('expires') ? params['upload']['expires'] : nil,
        'filesize' => @filesize,
        'filehash' => @filehash,
        'filename' => @uploaded.original_filename,
        'content_type' => @uploaded.content_type
      })  
    
      if !@upload.save
        render 'new'
      end
    end
    redirect_to :action => 'show', :identifier => @identifier 
  end

  def show
    destroy_expired
    @uploads = Upload.where('identifier = ? OR filename = ?', params[:identifier], params[:identifier])

    if @uploads.empty? or @uploads.length > 1
      render 'show'
      return
    end

    @upload = @uploads.first

    # Get the path and data
    @path = Rails.root.join('public', 'uploads', @upload['identifier'])
    @data = open(@path, "rb") {|f| f.read}

    # Check the params
    @disposition = params.has_key?('d') && params['d'] ? 'attachment': 'inline'
    
    if File.extname(@upload['filename']) == '.md' || (params.has_key?('md') && params['md'] && ['text', 'application'].include?(@upload.content_type.split('/')[0]))
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
        no_intra_emphasis: true, 
        fenced_code_blocks: true,   
        disable_indented_code_blocks: true
      )
      @data = markdown.render(@data).html_safe
      
      render 'show'
      return
    end

    send_data @data, type: @upload[:content_type], disposition: @disposition, filename: params[:identifier]
  end

  def destroy
    @uploads = Upload.where('identifier = ? OR filename = ?', params[:identifier], params[:identifier])

    if @uploads.length != 1
      redirect_to 'destroy'
      return
    end

    File.delete(Rails.root.join('public', 'uploads', @uploads.first['identifier']))

    @uploads.destroy_all
  
    redirect_to ''
  end

  private
  def generate_identifier
    # Ensure id does not already exist in database
    begin
      @identifier = [*('A'..'Z'),*('0'..'9'),*('a'..'z')].sample(3).join
    end until Upload.where(:identifier => @identifier).empty?

    return @identifier
  end

  def destroy_expired
    @uploads = Upload.where('expires IS NOT NULL AND expires < ?', DateTime.now)
    for @upload in @uploads.all do
      File.delete(Rails.root.join('public', 'uploads', @upload['identifier']))
    end
    @uploads.destroy_all
  end

end
