namespace Masafet_Elseka.Application.Interfaces.IPrivateFileStorage
{
    // Files that must never be publicly reachable (ID cards, licences). Stored on the
    // server's private volume and streamed only through authorised endpoints.
    public interface IPrivateFileStorage
    {
        Task<string> SaveAsync(Stream content, string folder, string extension);
        Task<byte[]?> ReadAsync(string relativePath);
        void Delete(string relativePath);
    }
}
