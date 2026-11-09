#include <std_include.hpp>
#include "loader/component_loader.hpp"

#include "game/game.hpp"

#include "filesystem.hpp"
#include "console.hpp"

#include <utils/hook.hpp>
#include <utils/io.hpp>
#include <utils/memory.hpp>
#include <utils/string.hpp>

#define MAX_ARENAS 64

namespace arena
{
	namespace
	{
		std::recursive_mutex arena_mutex;

		bool parse_arena(const std::string& path)
		{
			std::lock_guard<std::recursive_mutex> _0(arena_mutex);

			std::string buffer{};
			if (utils::io::read_file(path, &buffer) && !buffer.empty())
			{
				*game::ui_num_arenas += game::GameInfo_ParseArenas(buffer.data(), MAX_ARENAS - *game::ui_num_arenas,
					&game::ui_arena_infos[*game::ui_num_arenas]);
				return true;
			}

			if (!game::DB_XAssetExists(game::ASSET_TYPE_RAWFILE, path.data()) ||
				game::DB_IsXAssetDefault(game::ASSET_TYPE_RAWFILE, path.data()))
			{
				return false;
			}

			const auto* rawfile = game::DB_FindXAssetHeader(game::ASSET_TYPE_RAWFILE, path.data(), 0).rawfile;
			const auto len = game::DB_GetRawFileLen(rawfile);

			const auto rawfile_buffer = utils::memory::get_allocator()->allocate_array<char>(len);
			const auto _1 = gsl::finally([&]
			{
				utils::memory::get_allocator()->free(rawfile_buffer);
			});

			game::DB_GetRawBuffer(rawfile, rawfile_buffer, len);
			*game::ui_num_arenas += game::GameInfo_ParseArenas(rawfile_buffer, MAX_ARENAS - *game::ui_num_arenas,
				&game::ui_arena_infos[*game::ui_num_arenas]);
			
			return true;
		}

		// usermaps shipped without an .arena file (HMW's) get an entry made up
		// from their name so they show in the map list
		bool parse_generated_arena(const std::string& mapname)
		{
			std::lock_guard<std::recursive_mutex> _0(arena_mutex);

			if (*game::ui_num_arenas >= MAX_ARENAS)
			{
				return false;
			}

			std::string title = mapname.starts_with("mp_") ? mapname.substr(3) : mapname;
			for (auto& c : title)
			{
				c = (c == '_') ? ' ' : static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
			}

			const auto buffer = utils::string::va(
				"{\n\tmap\t\"%s\"\n\tlongname\t\"%s\"\n"
				"\tgametype\t\"war dom sd sab koth hq ctf dm gun oic\"\n}\n",
				mapname.data(), title.data());
			std::string text = buffer;
			*game::ui_num_arenas += game::GameInfo_ParseArenas(text.data(), MAX_ARENAS - *game::ui_num_arenas,
				&game::ui_arena_infos[*game::ui_num_arenas]);
			return true;
		}

		void load_arenas_stub()
		{
			*game::ui_num_arenas = 0;
			*game::ui_arena_buf_pos = 0;

			parse_arena("mp/basemaps.arena");

			// read all usermap arenas for map list
			for (const auto* dir : {"usermaps", "hmw-usermaps"})
			{
				if (!std::filesystem::exists(dir))
				{
					continue;
				}

				for (const auto& entry : std::filesystem::directory_iterator(dir))
				{
					if (!entry.is_directory())
					{
						continue;
					}

					auto mapname = entry.path().filename().string();
					auto arena_path = entry.path().string() + "/" + mapname + ".arena";

					if (!parse_arena(arena_path) && std::string(dir) == "hmw-usermaps" &&
						utils::io::file_exists(entry.path().string() + "/" + mapname + ".ff"))
					{
						parse_generated_arena(mapname);
					}
				}
			}
		}
	}

	class component final : public component_interface
	{
	public:
		void post_unpack() override
		{
			if (!game::environment::is_mp())
			{
				return;
			}

			// load custom arenas
			utils::hook::jump(0x4DE030_b, load_arenas_stub);
		}
	};
}

REGISTER_COMPONENT(arena::component)
