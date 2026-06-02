using Masafet_Elseka.Application.DTOs.Expense;
using Masafet_Elseka.Application.Interfaces.IExpenseService;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Masafet_Elseka.Presentation.Controllers
{
    [Authorize(Roles = "Admin, Accountant", AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Route("api/[controller]")]
    [ApiController]
    public class ExpenseController : ControllerBase
    {

        private readonly IExpenseService _expenseService;
        public ExpenseController(IExpenseService expenseService)
        {
            _expenseService = expenseService;
        }
        [HttpPost("AddExpens")]
        public async Task<IActionResult> AddExpense([FromBody] AddExpenseDTO model)
        {
            var response = await _expenseService.AddExpense(model);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, new { response.Data });
            }
            return StatusCode(response.StatusCode, new { response.Message });
        }

        [HttpGet("GetAllExpenses")]
        public async Task<IActionResult> GetAllExpenses([FromQuery] string? filter, [FromQuery] int skip = 0, [FromQuery] int take = 15)
        {
            var response = await _expenseService.GetAll(filter, skip, take);
            if (response.IsSuccess)
            {
                return StatusCode(response.StatusCode, response.Data);
            }
            return StatusCode(response.StatusCode, new { response.Message });
        }

        [HttpDelete("DeleteExpense/{id}")]
        public async Task<IActionResult> DeleteExpense(string id)
        {
            var response = await _expenseService.DeleteExpense(id);
            return StatusCode(response.StatusCode, new { response.Message });
        }
    }
}
