using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;

namespace Cinema_Ticketing___Seat_Booking
{
    /// <summary>ข้อผิดพลาดที่ "ผู้ใช้อ่านรู้เรื่อง" (เช่น จาก THROW ของ SP) แสดงข้อความนี้บนหน้าเว็บได้เลย</summary>
    public class BusinessException : Exception
    {
        public int Code { get; private set; }
        public BusinessException(string message, int code = 0) : base(message) { Code = code; }
    }

    /// <summary>ชั้นเข้าถึงฐานข้อมูลระดับล่าง: ใช้ SqlParameter และ using ทุกครั้ง ไม่มีการต่อสตริง SQL จากข้อมูลผู้ใช้</summary>
    public static class Db
    {
        const string GenericError = "ระบบขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง";

        static string ConnStr
        {
            get
            {
                ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings["CinemaDb"];
                if (cs == null) throw new BusinessException("ยังไม่ได้ตั้งค่า connection string ชื่อ CinemaDb ใน Web.config");
                return cs.ConnectionString;
            }
        }

        // ---------- ตัวช่วยสร้าง SqlParameter แบบกำหนดชนิดชัดเจน ----------
        public static SqlParameter Int(string name, int? v)
        {
            return new SqlParameter(name, SqlDbType.Int) { Value = v.HasValue ? (object)v.Value : DBNull.Value };
        }
        public static SqlParameter VarChar(string name, string v, int size)
        {
            return new SqlParameter(name, SqlDbType.VarChar, size) { Value = (object)v ?? DBNull.Value };
        }
        public static SqlParameter NVarChar(string name, string v, int size)
        {
            return new SqlParameter(name, SqlDbType.NVarChar, size) { Value = (object)v ?? DBNull.Value };
        }
        public static SqlParameter NVarCharMax(string name, string v)
        {
            return new SqlParameter(name, SqlDbType.NVarChar, -1) { Value = (object)v ?? DBNull.Value };
        }
        public static SqlParameter Dec(string name, decimal? v)
        {
            return new SqlParameter(name, SqlDbType.Decimal) { Precision = 10, Scale = 2, Value = v.HasValue ? (object)v.Value : DBNull.Value };
        }
        public static SqlParameter Date(string name, DateTime? v)
        {
            return new SqlParameter(name, SqlDbType.Date) { Value = v.HasValue ? (object)v.Value.Date : DBNull.Value };
        }
        public static SqlParameter DateTime2(string name, DateTime? v)
        {
            return new SqlParameter(name, SqlDbType.DateTime2) { Value = v.HasValue ? (object)v.Value : DBNull.Value };
        }

        // ---------- แปลง SqlException เป็นข้อความที่ผู้ใช้อ่านรู้เรื่อง (ไม่เปิดเผย stack trace) ----------
        public static Exception Translate(SqlException ex)
        {
            if (ex.Number >= 50000 && ex.Number < 60000)       // THROW จาก SP/Trigger ของเรา (ข้อความเป็นภาษาไทยอยู่แล้ว)
                return new BusinessException(ex.Message, ex.Number);

            Trace.TraceError("SQL error " + ex.Number + ": " + ex);

            switch (ex.Number)
            {
                case 547:
                    if (ex.Message.IndexOf("DELETE", StringComparison.OrdinalIgnoreCase) >= 0)
                        return new BusinessException("ไม่สามารถลบได้ เพราะมีข้อมูลอื่นอ้างอิงอยู่ (เช่น รอบฉายหรือการจอง) ให้เปลี่ยนสถานะแทนการลบ", 547);
                    return new BusinessException("ข้อมูลไม่เป็นไปตามกฎของระบบ กรุณาตรวจสอบค่าที่กรอก", 547);
                case 2601:
                case 2627:
                    return new BusinessException("ข้อมูลนี้ซ้ำกับที่มีอยู่แล้ว", ex.Number);
                case 1205:
                    return new BusinessException("มีผู้ใช้อื่นกำลังทำรายการพร้อมกัน กรุณาลองใหม่อีกครั้ง", 1205);
                case -2:
                    return new BusinessException("ฐานข้อมูลตอบสนองช้าเกินไป กรุณาลองใหม่อีกครั้ง", -2);
                default:
                    return new BusinessException(GenericError, ex.Number);
            }
        }

        static DataTable Run(string text, CommandType type, SqlParameter[] ps)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(ConnStr))
                using (SqlCommand cmd = new SqlCommand(text, conn))
                {
                    cmd.CommandType = type;
                    cmd.CommandTimeout = 20;
                    if (ps != null && ps.Length > 0) cmd.Parameters.AddRange(ps);
                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        DataTable dt = new DataTable();
                        da.Fill(dt);
                        return dt;
                    }
                }
            }
            catch (SqlException ex)
            {
                throw Translate(ex);
            }
            catch (InvalidOperationException ex)   // เช่น connection string ผิด
            {
                Trace.TraceError(ex.ToString());
                throw new BusinessException("ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาตรวจสอบการตั้งค่า");
            }
        }

        public static DataTable Query(string sql, params SqlParameter[] ps) { return Run(sql, CommandType.Text, ps); }
        public static DataTable Proc(string name, params SqlParameter[] ps) { return Run(name, CommandType.StoredProcedure, ps); }

        public static object Scalar(string sql, params SqlParameter[] ps)
        {
            DataTable dt = Run(sql, CommandType.Text, ps);
            return dt.Rows.Count == 0 || dt.Columns.Count == 0 ? null : dt.Rows[0][0];
        }

        public static int Execute(string sql, params SqlParameter[] ps)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(ConnStr))
                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.CommandTimeout = 20;
                    if (ps != null && ps.Length > 0) cmd.Parameters.AddRange(ps);
                    conn.Open();
                    return cmd.ExecuteNonQuery();
                }
            }
            catch (SqlException ex) { throw Translate(ex); }
            catch (InvalidOperationException ex)
            {
                Trace.TraceError(ex.ToString());
                throw new BusinessException("ไม่สามารถเชื่อมต่อฐานข้อมูลได้ กรุณาตรวจสอบการตั้งค่า");
            }
        }

        /// <summary>เรียก SP ที่คืน result set แบบ error_number/error_message เมื่อล้มเหลว (sp_HoldSeats ฯลฯ) แล้วแปลงเป็น BusinessException</summary>
        public static DataTable ProcChecked(string name, params SqlParameter[] ps)
        {
            DataTable dt = Proc(name, ps);
            if (dt.Columns.Contains("error_number") && dt.Rows.Count > 0)
            {
                int code = Convert.ToInt32(dt.Rows[0]["error_number"]);
                string msg = Convert.ToString(dt.Rows[0]["error_message"]);
                if (code >= 50000 && code < 60000) throw new BusinessException(msg, code);
                Trace.TraceError("SP " + name + " error " + code + ": " + msg);
                throw new BusinessException(GenericError, code);
            }
            return dt;
        }
    }
}
