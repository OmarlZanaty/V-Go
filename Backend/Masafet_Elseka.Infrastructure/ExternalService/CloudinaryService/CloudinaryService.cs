using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Masafet_Elseka.Application.ExternalInterfaces.ICloudinaryService;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Masafet_Elseka.Infrastructure.ExternalService.CloudinaryService
{
    public class CloudinaryService:ICloudinaryService
    {
        private readonly Cloudinary _cloudinary;

        public CloudinaryService(IConfiguration configuration)
        {
            var account = new Account
            {
                Cloud = configuration["Cloudinary:CloudName"],
                ApiKey = configuration["Cloudinary:ApiKey"],
                ApiSecret = configuration["Cloudinary:ApiSecret"]
            };

            _cloudinary = new Cloudinary(account);
        }


        public async Task<(string PublicId, string Url)> UploadFileAsync(IFormFile file, string folderName = "general")
        {
            if (file == null || file.Length == 0)
                return (string.Empty, string.Empty);

            var originalFileName = file.FileName;
            var fileExtension = Path.GetExtension(originalFileName).ToLower();
            var fileName = !string.IsNullOrEmpty(originalFileName)
                ? originalFileName
                : $"{Guid.NewGuid()}{fileExtension}";

            using var stream = file.OpenReadStream();

            bool isImage = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".svg", ".webp" }.Contains(fileExtension);

            var uploadParams = isImage
                ? new ImageUploadParams
                {
                    File = new FileDescription(fileName, stream),
                    Folder = folderName,
                    UseFilename = true,
                    UniqueFilename = true
                }
                : new RawUploadParams
                {
                    File = new FileDescription(fileName, stream),
                    Folder = folderName,
                    UseFilename = true,
                    UniqueFilename = false
                };

            var uploadResult = await _cloudinary.UploadAsync(uploadParams);

            string publicId = uploadResult.PublicId;
            string fileUrl = uploadResult.SecureUrl.ToString();

            return (publicId, fileUrl);
        }

        public async Task<bool> DeleteFileAsync(string publicId)
        {
            if (string.IsNullOrEmpty(publicId))
                return false;

            try
            {
                var resource = await _cloudinary.GetResourceAsync(new GetResourceParams(publicId));

                if (resource == null)
                {
                    //Console.WriteLine("File not found on Cloudinary.");
                    return false;
                }

                string resourceTypeString = resource.ResourceType.ToString().ToLower();

                ResourceType resourceType = resourceTypeString switch
                {
                    "image" => ResourceType.Image,
                    "video" => ResourceType.Video,
                    "raw" => ResourceType.Raw,
                    _ => ResourceType.Auto
                };

                var deletionParams = new DeletionParams(publicId)
                {
                    Invalidate = true,
                    ResourceType = resourceType
                };

                var deletionResult = await _cloudinary.DestroyAsync(deletionParams);

                return deletionResult.Result == "ok";
            }
            catch (Exception ex)
            {
                //Console.WriteLine($"Error deleting file: {ex.Message}");
                return false;
            }
        }



        string ICloudinaryService.GetFileUrl(string path)
        {
            throw new NotImplementedException();
        }


    }
}
