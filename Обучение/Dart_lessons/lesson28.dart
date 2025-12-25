void main() {
  final game = MinecraftGame();
  game.playerMove();
  game.playerBuild();
  game.playerDestroy();
  game.playerCraft();
  print(game.level);
}

class MinecraftGame {
  int level = 0;
  void playerMove() {
    print('Player mooving');
    level += 1;
  }

  void playerBuild() {
    print('Player build');
    level += 1;
  }
}

extension MinecraftGameDestroyExtension on MinecraftGame {
  void playerDestroy() {
    print('Player broken');
    level += 1;
  }
}

extension MinecraftGameCraftExtension on MinecraftGame {
  void playerCraft() {
    print('Player crafting');
    level += 1;
  }
}
